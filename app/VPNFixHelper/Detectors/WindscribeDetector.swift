import Foundation

final class WindscribeDetector: VPNClientDetector {
    let clientType: VPNClientType = .windscribe

    private let appPath = "/Applications/Windscribe.app"
    private let processName = "Windscribe"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes) ||
                        (DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                         DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes))

        let hasKillSwitch = cache.pfAnchors.contains { $0.lowercased().contains("windscribe") }

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "Windscribe firewall pf rules still active"
            ))
        }

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "Windscribe routes still active but app not running"
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
