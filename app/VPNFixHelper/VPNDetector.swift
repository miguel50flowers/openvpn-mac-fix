import Foundation

/// Multi-VPN coordinator — iterates all pluggable detectors and aggregates results.
/// Backward compatible: `currentState()` still returns a single VPNState for the menu bar.
final class VPNDetector {
    private let detectors: [VPNClientDetector]
    private let customDetector = CustomVPNDetector()

    init() {
        self.detectors = [
            OpenVPNDetector(),
            WireGuardDetector(),
            NordVPNDetector(),
            ExpressVPNDetector(),
            SurfsharkDetector(),
            CyberGhostDetector(),
            ProtonVPNDetector(),
            MullvadDetector(),
            PIADetector(),
            IPVanishDetector(),
            WindscribeDetector(),
            TunnelBearDetector(),
            CiscoAnyConnectDetector(),
            GlobalProtectDetector(),
            PulseSecureDetector(),
            ZscalerDetector(),
            FortiClientDetector(),
        ]
    }

    /// Fast VPN state check for 10s menu bar polling — only reads `netstat -rn`.
    /// Detects all VPN routing patterns: OpenVPN, WireGuard, FortiClient, GlobalProtect, IKEv2.
    /// The routing-table parsing lives in the pure `VPNStateClassifier` (in Shared) so it is
    /// unit-tested without a live `netstat`. If the read times out/fails it returns `.unknown`
    /// rather than a false `.disconnected` (which previously caused state flapping and masked issues).
    func currentState() -> VPNState {
        let reading = DetectionUtilities.routingTableReading()
        guard reading.available else { return .unknown }
        return VPNStateClassifier.classify(netstatOutput: reading.value)
    }

    /// Builds an active network-health snapshot using real probes (DNS resolution, default route,
    /// orphaned tunnel interfaces). Each field is left `nil` when it could not be measured, so a
    /// timed-out probe never becomes a false "healthy" nor a false "issue". Runs system commands —
    /// call off the main thread.
    func networkHealthSnapshot() -> NetworkHealthSnapshot {
        let route = DetectionUtilities.routingTableReading()
        let processes = DetectionUtilities.runningProcessesReading()
        let interfaces = DetectionUtilities.activeInterfacesReading()

        let tunnelProcesses = ["openvpn", "wireguard-go", "pia-wireguard-go"]
        let tunnelRunning = processes.available
            && DetectionUtilities.isAnyProcessRunning(tunnelProcesses, in: processes.value)

        let hasRoute: Bool? = route.available
            ? DetectionUtilities.hasPhysicalDefaultRoute(in: route.value)
            : nil

        // Bounded probe (2 hosts × 2s) so folding health into detection can't stall the dashboard.
        // Returns true on the first host that resolves; only a genuinely broken resolver pays the
        // full ~4s. `nil` (all timed out) stays unknown — never a false "DNS failure".
        let dns = DetectionUtilities.dnsResolves(hosts: ["apple.com", "cloudflare.com"], timeout: 2)

        let orphaned: Bool?
        if interfaces.available && route.available {
            let tunnelIfaceUp = interfaces.value.contains {
                ($0.name.hasPrefix("utun") || $0.name.hasPrefix("ppp")) && $0.address != nil
            }
            let routesViaTunnel = DetectionUtilities.hasRoute("0/1", via: "utun", in: route.value)
                || DetectionUtilities.hasDefaultRouteVia("utun", in: route.value)
                || route.value.contains("ppp0")
            orphaned = (tunnelIfaceUp || routesViaTunnel) && !tunnelRunning
        } else {
            orphaned = nil
        }

        return NetworkHealthSnapshot(
            dnsResolves: dns,
            hasDefaultRoute: hasRoute,
            gatewayReachable: nil,
            orphanedTunnelInterface: orphaned,
            staleVPNDns: nil,
            tunnelProcessRunning: tunnelRunning
        )
    }

    /// Detects all VPN clients. Returns only installed or running clients.
    func detectAll() -> [VPNClientStatus] {
        let cache = DetectionCache()
        HelperLogger.shared.debug("[VPNDetector] Running detection for \(detectors.count) VPN clients...")
        let allStatuses = detectors.map { detector -> VPNClientStatus in
            let status = detector.detect(using: cache)
            if status.installed || status.running {
                HelperLogger.shared.debug("[VPNDetector] \(status.clientType.displayName): installed=\(status.installed), running=\(status.running), state=\(status.connectionState.rawValue), issues=\(status.issueCount)")
            }
            return status
        }
        // Append custom VPN detections
        let customStatuses = customDetector.detectAll(using: cache)

        // Return only clients that are installed or running
        var statuses = (allStatuses + customStatuses).filter { $0.installed || $0.running }

        // Fold ACTIVE network-health issues in as a synthetic "Network" entry, but ONLY when no VPN
        // is currently connected. This closes the exact gap the user hit — VPN reads
        // "disconnected, 0 issues" while the internet is actually broken — without probing (and
        // slowing) the path when a tunnel is up and presumably carrying traffic. The entry rides
        // the same UI + issue count as VPN clients, so the menu bar badge reflects it too.
        let anyConnected = statuses.contains { $0.connectionState == .connected }
        if !anyConnected {
            let healthIssues = NetworkHealthClassifier.issues(from: networkHealthSnapshot())
            if !healthIssues.isEmpty {
                HelperLogger.shared.info("[VPNDetector] Network-health issues: \(healthIssues.map { $0.type.rawValue }.joined(separator: ", "))")
                statuses.append(VPNClientStatus(
                    clientType: .network,
                    installed: true,
                    running: false,
                    connectionState: .disconnected,
                    detectedIssues: healthIssues,
                    interfaceName: nil,
                    processName: nil,
                    appPath: nil))
            }
        }

        return statuses
    }

    /// Computes the aggregate state for the menu bar.
    func aggregateState() -> AggregateVPNState {
        let statuses = detectAll()
        let activeCount = statuses.filter { $0.connectionState == .connected }.count
        let issueCount = statuses.reduce(0) { $0 + $1.issueCount }

        if issueCount > 0 {
            return .issuesDetected(count: issueCount)
        } else if activeCount > 0 {
            return .vpnActive(count: activeCount)
        } else {
            return .allClear
        }
    }

    /// Collects network diagnostics snapshot.
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        let cache = DetectionCache(includeProcesses: false)
        let routes = cache.routingTable
        return NetworkDiagnostics(
            dnsServers: cache.dnsServers,
            defaultGateway: DetectionUtilities.getDefaultGateway(from: routes),
            publicIP: nil, // Populated asynchronously by the app if needed
            activeInterfaces: cache.activeInterfaces,
            pfRulesActive: !cache.pfAnchors.isEmpty,
            proxyConfigured: isProxyConfigured(cache.proxySettings),
            timestamp: Date()
        )
    }

    private func isProxyConfigured(_ settings: [String: String]) -> Bool {
        let proxyKeys = ["HTTPEnable", "HTTPSEnable", "SOCKSEnable", "ProxyAutoConfigEnable"]
        return proxyKeys.contains { settings[$0] == "1" }
    }
}
