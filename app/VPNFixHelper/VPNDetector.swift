import Foundation

/// Multi-VPN coordinator — iterates all pluggable detectors and aggregates results.
/// Backward compatible: `currentState()` still returns a single VPNState for the menu bar.
final class VPNDetector {
    private let detectors: [VPNClientDetector]
    private let cache = DetectionCache()

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

    /// Backward-compatible single state for the menu bar.
    func currentState() -> VPNState {
        HelperLogger.shared.debug("[VPNDetector] VPN state detection requested")
        let statuses = detectAll()
        let connected = statuses.filter { $0.running && $0.connectionState == .connected }
        let withIssues = statuses.filter { $0.hasIssues }

        let result: VPNState
        if !connected.isEmpty {
            result = .connected
        } else if !withIssues.isEmpty {
            result = .disconnected
        } else {
            result = .disconnected
        }
        HelperLogger.shared.debug("[VPNDetector] Aggregate state: \(result.rawValue) (connected=\(connected.count), issues=\(withIssues.count))")
        return result
    }

    /// Detects all VPN clients. Returns only installed or running clients.
    func detectAll() -> [VPNClientStatus] {
        HelperLogger.shared.debug("[VPNDetector] Running detection for \(detectors.count) VPN clients...")
        let allStatuses = detectors.map { detector -> VPNClientStatus in
            let status = detector.detect(using: cache)
            if status.installed || status.running {
                HelperLogger.shared.debug("[VPNDetector] \(status.clientType.displayName): installed=\(status.installed), running=\(status.running), state=\(status.connectionState.rawValue), issues=\(status.issueCount)")
            }
            return status
        }
        // Return only clients that are installed or running
        return allStatuses.filter { $0.installed || $0.running }
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
