import Foundation

final class PulseSecureDetector: VPNClientDetector {
    let clientType: VPNClientType = .pulseSecure

    private let appPath = "/Applications/Pulse Secure.app"
    private let processName = "dsAccessService"

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        // Also check for Ivanti Secure Access (rebrand)
        let installed = DetectionUtilities.isAppInstalled(at: appPath) ||
                        DetectionUtilities.isAppInstalled(at: "/Applications/Ivanti Secure Access.app")
        let running = DetectionUtilities.isProcessRunning(processName)
        var issues: [VPNIssue] = []

        let routes = cache.routingTable
        let hasUtunRoutes = cache.activeInterfaces.contains { $0.name.hasPrefix("utun") } &&
                            routes.contains("utun")

        // Check for DNS search domain corruption
        let dns = cache.dnsServers
        let hasCorporateDNS = dns.contains { $0.hasPrefix("10.") || $0.hasPrefix("172.") || $0.hasPrefix("192.168.") }

        if hasCorporateDNS && !running {
            issues.append(VPNIssue(
                type: .dnsLeak,
                severity: .high,
                description: "Corporate DNS search domains still configured after Pulse Secure disconnect"
            ))
        }

        if hasUtunRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .critical,
                description: "Pulse Secure routes still active but daemon not running"
            ))
        }

        let state: VPNState = (hasUtunRoutes && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasUtunRoutes ? "utun" : nil, processName: processName, appPath: appPath
        )
    }
}
