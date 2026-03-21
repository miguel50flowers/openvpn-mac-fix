import Foundation

/// Removes legacy Phase 1 installation artifacts (old daemon, scripts, temp files).
final class Phase1Migrator {

    func removeArtifacts(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[Phase1Migrator] removePhase1Artifacts requested")
        var removed: [String] = []
        var errors: [String] = []

        let fm = FileManager.default

        // Unload and remove old LaunchDaemon
        let plistPath = "/Library/LaunchDaemons/com.vpnmonitor.plist"
        if fm.fileExists(atPath: plistPath) {
            HelperLogger.shared.debug("[Phase1Migrator] Found Phase 1 plist: \(plistPath)")
            let unload = Process()
            unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unload.arguments = ["unload", plistPath]
            try? unload.run()
            unload.waitUntilExit()

            do {
                try fm.removeItem(atPath: plistPath)
                removed.append(plistPath)
                HelperLogger.shared.debug("[Phase1Migrator] Removed: \(plistPath)")
            } catch {
                HelperLogger.shared.error("[Phase1Migrator] Failed to remove \(plistPath): \(error.localizedDescription)")
                errors.append("Failed to remove \(plistPath): \(error.localizedDescription)")
            }
        }

        // Remove old scripts from all user home directories
        let userDirs = (try? fm.contentsOfDirectory(atPath: "/Users")) ?? []
        for user in userDirs where !user.hasPrefix(".") {
            let homePath = "/Users/\(user)"
            for script in ["vpn-monitor.sh", "fix-vpn-disconnect.sh"] {
                let scriptPath = "\(homePath)/\(script)"
                if fm.fileExists(atPath: scriptPath) {
                    HelperLogger.shared.debug("[Phase1Migrator] Found Phase 1 script: \(scriptPath)")
                    do {
                        try fm.removeItem(atPath: scriptPath)
                        removed.append(scriptPath)
                        HelperLogger.shared.debug("[Phase1Migrator] Removed: \(scriptPath)")
                    } catch {
                        HelperLogger.shared.error("[Phase1Migrator] Failed to remove \(scriptPath): \(error.localizedDescription)")
                        errors.append("Failed to remove \(scriptPath): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Clean up temp files
        for tmp in ["/tmp/vpn-was-connected"] {
            if fm.fileExists(atPath: tmp) {
                HelperLogger.shared.debug("[Phase1Migrator] Cleaning temp file: \(tmp)")
                try? fm.removeItem(atPath: tmp)
                removed.append(tmp)
            }
        }

        if errors.isEmpty {
            HelperLogger.shared.info("[Phase1Migrator] Phase 1 removal complete: \(removed.count) files removed")
            reply(true, "Removed: \(removed.joined(separator: ", "))")
        } else {
            HelperLogger.shared.error("[Phase1Migrator] Phase 1 removal had errors: \(errors.joined(separator: "; "))")
            reply(false, "Errors: \(errors.joined(separator: "; "))")
        }
    }
}
