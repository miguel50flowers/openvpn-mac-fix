import Foundation

final class WireGuardDetector: VPNClientDetector {
    let clientType: VPNClientType = .wireGuard

    private let appPath = "/Applications/WireGuard.app"
    private let processName = "wireguard-go"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []
        var interfaceName: String?

        let routes = cache.routingTable
        let hasDefaultUtun = DetectionUtilities.hasDefaultRouteVia("utun", in: routes)

        if hasDefaultUtun {
            interfaceName = "utun"
        }

        if hasDefaultUtun && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "WireGuard default route via utun active but wireguard-go not running"
            ))
        }

        let state: VPNState = (hasDefaultUtun && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: interfaceName, processName: processName, appPath: appPath
        )
    }
}
