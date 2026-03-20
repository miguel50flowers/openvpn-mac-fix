import Foundation

final class IPVanishDetector: VPNClientDetector {
    let clientType: VPNClientType = .ipVanish

    private let appPath = "/Applications/IPVanish VPN.app"
    private let processName = "IPVanish"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes) ||
                        (DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                         DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes))

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "IPVanish routes still active but app not running"
            ))
        }

        let state: VPNState = (hasRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasRoutes ? "utun" : nil, processName: processName, appPath: appPath
        )
    }
}
