import Foundation

/// Detects OpenVPN Connect — checks for signature routes 0/1 + 128.0/1 via utun.
final class OpenVPNDetector: VPNClientDetector {
    let clientType: VPNClientType = .openVPN

    private let appPath = "/Applications/OpenVPN Connect.app"
    private let processName = "openvpn"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isProcessRunning(processName)

        var issues: [VPNIssue] = []
        var interfaceName: String?

        let routes = cache.routingTable
        let has0slash1 = DetectionUtilities.hasRoute("0/1", via: "utun", in: routes)
        let has128slash1 = DetectionUtilities.hasRoute("128.0/1", via: "utun", in: routes)
        let hasOpenVPNRoutes = has0slash1 && has128slash1

        if hasOpenVPNRoutes {
            interfaceName = findUtunInterface(in: routes)
        }

        // Detect stale routes: OpenVPN routes exist but process not running
        if hasOpenVPNRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "OpenVPN routes (0/1, 128.0/1) still active but openvpn process not running"
            ))
        }

        let state: VPNState
        if hasOpenVPNRoutes && running {
            state = .connected
        } else if !issues.isEmpty {
            state = .disconnected
        } else if installed {
            state = .disconnected
        } else {
            state = .unknown
        }

        return VPNClientStatus(
            clientType: clientType,
            installed: installed,
            running: running,
            connectionState: state,
            detectedIssues: issues,
            interfaceName: interfaceName,
            processName: processName,
            appPath: appPath
        )
    }

    private func findUtunInterface(in routes: String) -> String? {
        for line in routes.components(separatedBy: .newlines) {
            if (line.hasPrefix("0/1") || line.contains(" 0/1 ")), line.contains("utun") {
                let parts = line.split(separator: " ").map(String.init)
                return parts.last { $0.hasPrefix("utun") }
            }
        }
        return nil
    }
}
