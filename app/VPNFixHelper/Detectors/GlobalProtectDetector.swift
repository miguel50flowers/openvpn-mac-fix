import Foundation

final class GlobalProtectDetector: VPNClientDetector {
    let clientType: VPNClientType = .globalProtect

    private let appPath = "/Applications/GlobalProtect.app"
    private let processName = "PanGPS"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        // GlobalProtect uses unique gpd0 interface, sometimes utun
        let hasGPD = routes.contains("gpd0")
        let hasUtun = cache.activeInterfaces.contains { $0.name.hasPrefix("utun") } &&
                      routes.contains("utun")
        let hasRoutes = hasGPD || hasUtun

        let hasKillSwitch = cache.pfAnchors.contains { $0.contains("GlobalProtect") }

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "GlobalProtect pf rules still active"
            ))
        }

        if hasGPD && !running {
            issues.append(VPNIssue(
                type: .orphanedInterface,
                severity: .high,
                description: "GlobalProtect gpd0 interface still present after disconnect"
            ))
        }

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "GlobalProtect routes still active but PanGPS not running"
            ))
        }

        let state: VPNState = (hasRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasGPD ? "gpd0" : (hasUtun ? "utun" : nil),
            processName: processName, appPath: appPath
        )
    }
}
