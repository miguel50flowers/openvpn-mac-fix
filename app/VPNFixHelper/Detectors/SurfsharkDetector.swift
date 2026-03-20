import Foundation

final class SurfsharkDetector: VPNClientDetector {
    let clientType: VPNClientType = .surfshark

    private let appPath = "/Applications/Surfshark.app"
    private let processName = "surfsharkd"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes) ||
                        (DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                         DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes))

        // Check pf anchors
        let hasKillSwitch = cache.pfAnchors.contains { $0.contains("Surfshark") }

        // Check SOCKS proxy
        let proxy = cache.proxySettings
        let hasProxy = proxy["SOCKSEnable"] == "1"

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "Surfshark kill switch pf rules still active"
            ))
        }

        if hasProxy && !running {
            issues.append(VPNIssue(
                type: .staleProxy,
                severity: .high,
                description: "Surfshark SOCKS proxy still configured"
            ))
        }

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "Surfshark routes still active but daemon not running"
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
