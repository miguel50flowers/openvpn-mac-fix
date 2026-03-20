import Foundation

/// Protocol for pluggable per-client VPN detection.
protocol VPNClientDetector {
    var clientType: VPNClientType { get }
    func detect(using cache: DetectionCache) -> VPNClientStatus
}

/// Cached system state shared across all detectors within a single detection cycle.
/// Create a new instance for each detection cycle to ensure fresh data.
final class DetectionCache {
    let runningProcesses: Set<String>
    let routingTable: String
    let pfAnchors: [String]
    let dnsServers: [String]
    let proxySettings: [String: String]
    let activeInterfaces: [NetworkInterface]

    init(includeProcesses: Bool = true) {
        self.runningProcesses = includeProcesses ? DetectionUtilities.getRunningProcesses() : []
        self.routingTable = DetectionUtilities.getRoutingTable()
        self.pfAnchors = DetectionUtilities.getPfAnchors()
        self.dnsServers = DetectionUtilities.getDNSServers()
        self.proxySettings = DetectionUtilities.getProxySettings()
        self.activeInterfaces = DetectionUtilities.getActiveInterfaces()
    }
}
