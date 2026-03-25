import Foundation

/// Creates a fresh network location with default settings — macOS equivalent of "netsh winsock reset".
final class NetworkLocationResetModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[LocationReset] Creating fresh network location")

        let locationName = "VPNFix-Clean"

        // Delete existing VPNFix-Clean location if present
        _ = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-deletelocation", locationName])

        // Create new location with auto-populated services
        let create = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-createlocation", locationName, "populate"])
        guard create.succeeded else {
            HelperLogger.shared.error("[LocationReset] Failed to create location (exit \(create.exitCode))")
            completion(false, "Failed to create network location")
            return
        }

        // Switch to the new clean location
        let switchResult = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-switchtolocation", locationName])
        if switchResult.succeeded {
            HelperLogger.shared.info("[LocationReset] Switched to clean network location")
            completion(true, "Switched to clean network location '\(locationName)'")
        } else {
            completion(false, "Created location but failed to switch")
        }
    }
}
