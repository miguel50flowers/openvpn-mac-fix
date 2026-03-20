import Foundation

final class ProtonVPNDetector: VPNClientDetector {
    let clientType: VPNClientType = .protonVPN

    private let appPath = "/Applications/Proton VPN.app"
    private let processName = "ProtonVPN"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes) ||
                        (DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                         DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes))

        let hasKillSwitch = cache.pfAnchors.contains { $0.contains("ProtonVPN") }

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "Proton VPN kill switch pf rules still active but app not running"
            ))
        }

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "Proton VPN routes still active but app not running"
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
