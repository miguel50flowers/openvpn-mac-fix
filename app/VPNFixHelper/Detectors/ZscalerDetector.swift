import Foundation

final class ZscalerDetector: VPNClientDetector {
    let clientType: VPNClientType = .zscaler

    private let appPath = "/Applications/Zscaler/Zscaler.app"
    private let processNames = ["ZscalerService", "ZscalerTunnel", "zscaler"]

    func detect(using cache: DetectionCache) -> VPNClientStatus {
        let installed = DetectionUtilities.isAppInstalled(at: appPath)
        let running = DetectionUtilities.isAnyProcessRunning(processNames, in: cache.runningProcesses)
        let matchedProcess = DetectionUtilities.firstRunningProcess(processNames, in: cache.runningProcesses)
        var issues: [VPNIssue] = []

        // Zscaler uses localhost:9000 proxy model rather than routes
        let proxy = cache.proxySettings
        let hasProxy = proxy["HTTPEnable"] == "1" || proxy["HTTPSEnable"] == "1"
        let hasPAC = proxy["ProxyAutoConfigEnable"] == "1"

        if (hasProxy || hasPAC) && !running {
            issues.append(VPNIssue(
                type: .staleProxy,
                severity: .critical,
                description: "Zscaler proxy/PAC settings still configured but service not running"
            ))
        }

        let routes = cache.routingTable
        let hasUtunRoutes = routes.contains("utun")

        if hasUtunRoutes && !running {
            issues.append(VPNIssue(
                type: .staleRoutes,
                severity: .high,
                description: "Zscaler tunnel routes still active"
            ))
        }

        let connected = running && (hasProxy || hasPAC || hasUtunRoutes)
        let state: VPNState = connected ? .connected : .disconnected

        return VPNClientStatus(
            clientType: clientType, installed: installed, running: running,
            connectionState: state, detectedIssues: issues,
            interfaceName: hasUtunRoutes ? "utun" : nil, processName: matchedProcess ?? processNames[0], appPath: appPath
        )
    }
}
