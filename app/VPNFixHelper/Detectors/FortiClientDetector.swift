import Foundation

final class FortiClientDetector: VPNClientDetector {
    let clientType: VPNClientType = .fortiClient

    private let appPath = "/Applications/FortiClient.app"
    private let processName = "fct_launcher"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        // FortiClient uses ppp0 or utun
        let hasPPP = routes.contains("ppp0")
        let hasUtun = cache.activeInterfaces.contains { $0.name.hasPrefix("utun") } &&
                      routes.contains("utun")
        let hasRoutes = hasPPP || hasUtun

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

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "FortiClient routes still active but launcher not running"
            ))
        }

        let state: VPNState = (hasRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasPPP ? "ppp0" : (hasUtun ? "utun" : nil),
            processName: processName, appPath: appPath
        )
    }
}
