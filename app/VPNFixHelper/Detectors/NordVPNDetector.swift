import Foundation

final class NordVPNDetector: VPNClientDetector {
    let clientType: VPNClientType = .nordVPN

    private let appPath = "/Applications/NordVPN.app"
    private let processName = "nordvpnd"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        // NordVPN uses either WireGuard (NordLynx) or OpenVPN
        let hasWGRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes)
        let hasOVPNRoutes = DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                            DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes)
        let hasVPNRoutes = hasWGRoutes || hasOVPNRoutes

        // Check for kill switch pf rules
        let pfRules = cache.pfAnchors
        let hasKillSwitch = pfRules.contains { $0.contains("NordVPN") }

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "NordVPN kill switch pf rules still active but daemon not running"
            ))
        }

        if hasVPNRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "NordVPN routes still active but daemon not running"
            ))
        }

        let state: VPNState = (hasVPNRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasVPNRoutes ? "utun" : nil, processName: processName, appPath: appPath
        )
    }
}
