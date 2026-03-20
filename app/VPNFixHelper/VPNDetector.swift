import Foundation

/// Multi-VPN coordinator — iterates all pluggable detectors and aggregates results.
/// Backward compatible: `currentState()` still returns a single VPNState for the menu bar.
final class VPNDetector {
    private let detectors: [VPNClientDetector]

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
    func currentState() -> VPNState {
        let output = DetectionUtilities.runCommand("/usr/sbin/netstat", arguments: ["-rn"])
        let lines = output.components(separatedBy: .newlines)
        var has0slash1 = false
        var has128slash1 = false
        for line in lines where line.contains("utun") {
            if line.hasPrefix("0/1") || line.contains(" 0/1 ") { has0slash1 = true }
            if line.hasPrefix("128.0/1") || line.contains(" 128.0/1 ") { has128slash1 = true }
        }
        return (has0slash1 && has128slash1) ? .connected : .disconnected
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
        let cache = DetectionCache()
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
