import Foundation

final class PIADetector: VPNClientDetector {
    let clientType: VPNClientType = .pia

    private let appPath = "/Applications/Private Internet Access.app"
    private let processNames = ["pia-daemon", "pia-wireguard-go"]

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isAnyProcessRunning(processNames, in: cache.runningProcesses)
        let matchedProcess = DetectionUtilities.firstRunningProcess(processNames, in: cache.runningProcesses)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasOVPN = DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                      DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes)
        let hasWG = DetectionUtilities.hasDefaultRouteVia("utun", in: routes)
        let hasRoutes = hasOVPN || hasWG

        let hasKillSwitch = cache.pfAnchors.contains { $0.contains("pia") }

        if hasKillSwitch && !running {
            issues.append(VPNIssue(
                type: .killSwitchActive,
                severity: .critical,
                description: "PIA kill switch pf rules still active"
            ))
        }

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "PIA routes still active but daemon not running"
            ))
        }

        // PIA can leave multiple orphaned utun interfaces
        let utunCount = cache.activeInterfaces.filter { $0.name.hasPrefix("utun") }.count
        if utunCount > 2 && !running {
            issues.append(VPNIssue(
                type: .orphanedInterface,
                severity: .medium,
                description: "Multiple orphaned utun interfaces detected (\(utunCount))"
            ))
        }

        let state: VPNState = (hasRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasRoutes ? "utun" : nil, processName: matchedProcess ?? processNames[0], appPath: appPath
        )
    }
}
