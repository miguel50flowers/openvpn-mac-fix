import Foundation

final class CiscoAnyConnectDetector: VPNClientDetector {
    let clientType: VPNClientType = .ciscoAnyConnect

    private let appPath = "/Applications/Cisco/Cisco AnyConnect Secure Mobility Client.app"
    private let processNames = ["vpnagentd", "vpnui", "aciseagent"]

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isAnyProcessRunning(processNames, in: cache.runningProcesses)
        let matchedProcess = DetectionUtilities.firstRunningProcess(processNames, in: cache.runningProcesses)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        // AnyConnect routes corporate subnets via utun, not 0/1+128.0/1
        let hasUtunRoutes = cache.activeInterfaces.contains { $0.name.hasPrefix("utun") } &&
                            routes.contains("utun")

        // Check for DNS search domain corruption
        let dns = cache.dnsServers
        let hasLocalDNS = dns.contains { $0.hasPrefix("10.") || $0.hasPrefix("172.") || $0.hasPrefix("192.168.") }

        if hasLocalDNS && !running {
            issues.append(VPNIssue(
                type: .dnsLeak,
                severity: .high,
                description: "Corporate DNS servers still configured after AnyConnect disconnected"
            ))
        }

        // vpnagentd can persist even when not connected
        if running && !hasUtunRoutes {
            issues.append(VPNIssue(
                type: .daemonPersistence,
                severity: .low,
                description: "AnyConnect vpnagentd running but no active tunnel"
            ))
        }

        let connected = hasUtunRoutes && running
        let state: VPNState = connected ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasUtunRoutes ? "utun" : nil, processName: matchedProcess ?? processNames[0], appPath: appPath
        )
    }
}
