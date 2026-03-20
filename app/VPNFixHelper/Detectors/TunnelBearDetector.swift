import Foundation

final class TunnelBearDetector: VPNClientDetector {
    let clientType: VPNClientType = .tunnelBear

    private let appPath = "/Applications/TunnelBear.app"
    private let processName = "TunnelBear"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = cache.runningProcesses.contains(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                        DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes)

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .high,
                description: "TunnelBear routes still active but app not running"
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
