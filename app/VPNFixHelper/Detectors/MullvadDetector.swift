import Foundation

final class MullvadDetector: VPNClientDetector {
    let clientType: VPNClientType = .mullvad

    private let appPath = "/Applications/Mullvad VPN.app"
    private let processName = "mullvad-daemon"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = cache.runningProcesses.contains(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes)

        // Mullvad has the most aggressive pf kill switch
        let hasKillSwitch = cache.pfAnchors.contains { $0.contains("mullvad") }

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "Mullvad kill switch pf rules still active — this blocks ALL network traffic"
            ))
        }

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "Mullvad routes still active but daemon not running"
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
