import Foundation

/// Detects user-defined custom VPN clients from the persisted JSON configuration.
final class CustomVPNDetector {
    private let configPath = "/Library/PrivilegedHelperTools/VPNFixResources/custom-vpns.json"

    func detectAll(using cache: DetectionCache) -> [VPNClientStatus] {
        guard let data = FileManager.default.contents(atPath: configPath),
              let entries = try? JSONDecoder().decode([CustomVPNEntry].self, from: data) else {
            return []
        }

        return entries.compactMap { entry in
            detect(entry: entry, using: cache)
        }
    }

    private func detect(entry: CustomVPNEntry, using cache: DetectionCache) -> VPNClientStatus? {
        let installed = FileManager.default.fileExists(atPath: entry.appPath)
        let running = cache.runningProcesses.contains(entry.processName)

        guard installed || running else { return nil }

        let routes = cache.routingTable
        let hasInterface = routes.contains(entry.interfaceType.rawValue)
        let state: VPNState = (hasInterface && running) ? .connected : .disconnected

        return VPNClientStatus(
            clientType: .custom,
            installed: installed,
            running: running,
            connectionState: state,
            detectedIssues: [],
            interfaceName: hasInterface ? entry.interfaceType.rawValue : nil,
            processName: entry.processName,
            appPath: entry.appPath
        )
    }
}
