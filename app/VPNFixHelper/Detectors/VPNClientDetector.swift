import Foundation

/// Protocol for pluggable per-client VPN detection.
protocol VPNClientDetector {
    var clientType: VPNClientType { get }
    func detect(using cache: DetectionCache) -> VPNClientStatus
}

/// Cached system state shared across all detectors within a single detection cycle.
final class DetectionCache {
    private(set) lazy var routingTable: String = DetectionUtilities.getRoutingTable()
    private(set) lazy var pfAnchors: [String] = DetectionUtilities.getPfAnchors()
    private(set) lazy var dnsServers: [String] = DetectionUtilities.getDNSServers()
    private(set) lazy var proxySettings: [String: String] = DetectionUtilities.getProxySettings()
    private(set) lazy var activeInterfaces: [NetworkInterface] = DetectionUtilities.getActiveInterfaces()

    func reset() {
        // Force re-evaluation on next access by creating a new cache
    }
}
