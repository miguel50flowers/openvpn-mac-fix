import Foundation

// Sparkle is added as an SPM dependency.
// When Sparkle is available, this wraps SPUStandardUpdaterController.
// When building without Sparkle (e.g., initial dev), this is a no-op stub.

#if canImport(Sparkle)
import Sparkle

final class SparkleUpdater {
    static let shared = SparkleUpdater()

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        AppLogger.shared.debug("Sparkle updater controller initialized")
        applyCheckFrequency(AppPreferences.shared.updateCheckFrequency)
    }

    func applyCheckFrequency(_ frequency: String) {
        let humanReadable: String
        switch frequency {
        case "manual":
            controller.updater.automaticallyChecksForUpdates = false
            humanReadable = "manual (auto-check disabled)"
        case "daily":
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 86400
            humanReadable = "daily (every 24h)"
        case "weekly":
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 604800
            humanReadable = "weekly (every 7d)"
        case "monthly":
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 2592000
            humanReadable = "monthly (every 30d)"
        default: // "automatic"
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 86400
            humanReadable = "automatic (every 24h)"
        }
        AppLogger.shared.debug("Update check frequency set to: \(humanReadable)")
    }

    func checkForUpdates() {
        AppLogger.shared.info("Checking for updates...")
        controller.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}

#else

/// Stub when Sparkle is not linked (dev builds without SPM dependency).
final class SparkleUpdater {
    static let shared = SparkleUpdater()
    private init() {}

    func checkForUpdates() {
        NSLog("[VPNFix] Sparkle not available — skipping update check")
    }

    func applyCheckFrequency(_ frequency: String) {}

    var canCheckForUpdates: Bool { false }
}

#endif
