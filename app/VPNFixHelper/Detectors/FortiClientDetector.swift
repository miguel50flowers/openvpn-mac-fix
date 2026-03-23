import Foundation

final class FortiClientDetector: VPNClientDetector {
    let clientType: VPNClientType = .fortiClient

    private let appPath = "/Applications/FortiClient.app"
    private let processNames = ["fct_launcher", "fctservctl", "fctservctl2", "sslvpnd", "FortiClient", "FortiClientAgent"]

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isAnyProcessRunning(processNames, in: cache.runningProcesses)
        let matchedProcess = DetectionUtilities.firstRunningProcess(processNames, in: cache.runningProcesses)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        // FortiClient SSLVPN uses ppp0 (legacy) or utun (modern NE-based)
        let hasPPP0 = routes.contains("ppp0")
        let hasUtunTunnel = running && DetectionUtilities.hasUtunWithIPv4(in: cache.activeInterfaces)
        let hasRoutes = hasPPP0 || hasUtunTunnel

        // Check for DNS forwarder on 127.0.0.1:53
        let dns = cache.dnsServers
        let hasLocalDNS = dns.contains("127.0.0.1")

        if hasLocalDNS && !running {
            issues.append(VPNIssue(
                type: .dnsLeak,
                severity: .critical,
                description: "FortiClient DNS forwarder on 127.0.0.1:53 still active — DNS will fail"
            ))
        }

        if hasPPP0 && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "FortiClient routes still active but no FortiClient process running"
            ))
        }

        let state: VPNState = (hasRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasPPP0 ? "ppp0" : (hasUtunTunnel ? "utun" : nil),
            processName: matchedProcess ?? processNames[0], appPath: appPath
        )
    }
}
