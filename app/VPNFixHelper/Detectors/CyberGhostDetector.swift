import Foundation

final class CyberGhostDetector: VPNClientDetector {
    let clientType: VPNClientType = .cyberGhost

    private let appPath = "/Applications/CyberGhost VPN.app"
    private let processName = "cyberghostvpn"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasRoutes = DetectionUtilities.hasDefaultRouteVia("utun", in: routes) ||
                        (DetectionUtilities.hasRoute("0/1", via: "utun", in: routes) &&
                         DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes))

        if hasRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "CyberGhost routes still active but daemon not running"
            ))
        }

        // CyberGhost daemon can persist and consume CPU
        if running && !hasRoutes {
            issues.append(VPNIssue(
                type: .daemonPersistence,
                severity: .low,
                description: "CyberGhost daemon running but not connected"
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
