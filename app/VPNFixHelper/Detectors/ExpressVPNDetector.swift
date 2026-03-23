import Foundation

final class ExpressVPNDetector: VPNClientDetector {
    let clientType: VPNClientType = .expressVPN

    private let appPath = "/Applications/ExpressVPN.app"
    private let processNames = ["expressvpnd", "ExpressVPN", "Lightway"]

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isAnyProcessRunning(processNames, in: cache.runningProcesses)
        let matchedProcess = DetectionUtilities.firstRunningProcess(processNames, in: cache.runningProcesses)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        // ExpressVPN Lightway uses default via utun
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes)

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "ExpressVPN routes still active but daemon not running"
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
