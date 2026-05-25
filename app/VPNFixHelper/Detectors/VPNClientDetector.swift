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

    /// Availability flags: `false` means the underlying command timed out / failed, so the
    /// (empty) value must NOT be treated as a real negative. Detectors use these to avoid the
    /// silent-failure misclassification ("couldn't read" → false "no VPN / no issues").
    let processesAvailable: Bool
    let routingTableAvailable: Bool

    init(includeProcesses: Bool = true) {
        // Run the slow system reads concurrently: one hung command (common with content-filter
        // VPNs like FortiClient) must not serialize into a multi-second stall that cascades into
        // a storm of timeouts.
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.vpnfix.detection", attributes: .concurrent)

        var proc = DetectionUtilities.Read<Set<String>>(value: [], available: false)
        var route = DetectionUtilities.Read<String>(value: "", available: false)
        var pf = DetectionUtilities.Read<[String]>(value: [], available: false)
        var dns = DetectionUtilities.Read<[String]>(value: [], available: false)
        var proxy = DetectionUtilities.Read<[String: String]>(value: [:], available: false)
        var ifaces = DetectionUtilities.Read<[NetworkInterface]>(value: [], available: false)

        if includeProcesses {
            group.enter(); queue.async { proc = DetectionUtilities.runningProcessesReading(); group.leave() }
        }
        group.enter(); queue.async { route = DetectionUtilities.routingTableReading(); group.leave() }
        group.enter(); queue.async { pf = DetectionUtilities.pfAnchorsReading(); group.leave() }
        group.enter(); queue.async { dns = DetectionUtilities.dnsServersReading(); group.leave() }
        group.enter(); queue.async { proxy = DetectionUtilities.proxySettingsReading(); group.leave() }
        group.enter(); queue.async { ifaces = DetectionUtilities.activeInterfacesReading(); group.leave() }

        // Overall ceiling so a wedged command can't hang detection forever (each read already
        // self-terminates at detectionTimeout).
        _ = group.wait(timeout: .now() + DetectionUtilities.detectionTimeout + 3)

        self.runningProcesses = proc.value
        self.processesAvailable = includeProcesses && proc.available
        self.routingTable = route.value
        self.routingTableAvailable = route.available
        self.pfAnchors = pf.value
        self.dnsServers = dns.value
        self.proxySettings = proxy.value
        self.activeInterfaces = ifaces.value
    }
}
