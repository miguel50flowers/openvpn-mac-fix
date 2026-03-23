import Foundation

final class WireGuardDetector: VPNClientDetector {
    let clientType: VPNClientType = .wireGuard

    private let appPath = "/Applications/WireGuard.app"
    private let processNames = ["wireguard-go", "WireGuard"]

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isAnyProcessRunning(processNames, in: cache.runningProcesses)
        let matchedProcess = DetectionUtilities.firstRunningProcess(processNames, in: cache.runningProcesses)
        var issues: [VPNIssue] = []
        var interfaceName: String?

        let routes = cache.routingTable
        let hasDefaultUtun = DetectionUtilities.hasDefaultRouteVia("utun", in: routes)
        // WireGuard App Store version uses NE system extension — no visible process,
        // but creates utun with IPv4 address
        let hasUtunTunnel = DetectionUtilities.hasUtunWithIPv4(in: cache.activeInterfaces)
        let hasWGConnection = hasDefaultUtun || (installed && !running && hasUtunTunnel)

        if hasWGConnection {
            interfaceName = "utun"
        }

        if hasDefaultUtun && !running && !hasUtunTunnel {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "WireGuard default route via utun active but no WireGuard process running"
            ))
        }

        let connected = hasWGConnection && (running || (installed && hasUtunTunnel))
        let state: VPNState = connected ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: interfaceName, processName: matchedProcess ?? processNames[0], appPath: appPath
        )
    }
}
