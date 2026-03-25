import Foundation

/// Backs up and resets SystemConfiguration preference plists — nuclear network reset.
final class SystemConfigResetModule {
    private let configPath = "/Library/Preferences/SystemConfiguration"
    private let backupBase = "/Library/Preferences/SystemConfiguration-Backup"

    private let resetableFiles = [
        "com.apple.airport.preferences.plist",
        "com.apple.network.identification.plist",
        "NetworkInterfaces.plist",
        "preferences.plist"
    ]

    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[SysConfig] Backing up and resetting network preferences")

        // Create timestamped backup
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupPath = "\(backupBase)-\(formatter.string(from: Date()))"

        let mkdir = DetectionUtilities.runCommandWithStatus("/bin/mkdir", arguments: ["-p", backupPath])
        guard mkdir.succeeded else {
            completion(false, "Failed to create backup directory")
            return
        }

        // Backup each file
        var backedUp: [String] = []
        for file in resetableFiles {
            let src = "\(configPath)/\(file)"
            if FileManager.default.fileExists(atPath: src) {
                let cp = DetectionUtilities.runCommandWithStatus("/bin/cp", arguments: [src, "\(backupPath)/\(file)"])
                if cp.succeeded { backedUp.append(file) }
            }
        }

        // Delete the files (NOT com.apple.Boot.plist)
        var deleted: [String] = []
        for file in resetableFiles {
            let path = "\(configPath)/\(file)"
            if FileManager.default.fileExists(atPath: path) {
                let rm = DetectionUtilities.runCommandWithStatus("/bin/rm", arguments: ["-f", path])
                if rm.succeeded { deleted.append(file) }
            }
        }

        let msg = "Backed up \(backedUp.count) files to \(backupPath), deleted \(deleted.count) config files. Reboot required."
        HelperLogger.shared.info("[SysConfig] \(msg)")
        completion(true, msg)
    }
}
