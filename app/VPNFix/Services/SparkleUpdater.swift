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
        applyCheckFrequency(AppPreferences.shared.updateCheckFrequency)
    }

    func applyCheckFrequency(_ frequency: String) {
        switch frequency {
        case "manual":
            controller.updater.automaticallyChecksForUpdates = false
        case "daily":
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 86400
        case "weekly":
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 604800
        case "monthly":
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 2592000
        default: // "automatic"
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.updateCheckInterval = 86400
        }
    }

    func checkForUpdates() {
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
