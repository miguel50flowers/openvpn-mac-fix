import SwiftUI

@main
struct VPNFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vpnStatus = VPNStatusViewModel()

    var body: some Scene {
        MenuBarExtra("VPN Fix", systemImage: vpnStatus.state.sfSymbol) {
            MenuBarView(viewModel: vpnStatus)
        }

        Window("VPN Fix", id: "dashboard") {
            DashboardView()
        }
        .defaultSize(width: 800, height: 600)

        Window("Log Viewer", id: "log-viewer") {
            LogViewerView()
        }
        .defaultSize(width: 700, height: 500)

        Settings {
            PreferencesView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notificationService = NotificationService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("VPN Fix app launched")
        let showDock = AppPreferences.shared.showDockIcon
        AppLogger.shared.debug("Dock icon policy: \(showDock ? "regular (visible)" : "accessory (hidden)")")
        if showDock {
            NSApp.setActivationPolicy(.regular)
        }
        AppLogger.shared.debug("Requesting notification permission...")
        notificationService.requestPermission()
        AppLogger.shared.debug("Checking helper install status...")
        HelperInstaller.shared.installIfNeeded()
        AppLogger.shared.debug("Checking for Phase 1 migration...")
        checkForPhase1Migration()

        if AppPreferences.shared.showDashboardOnLaunch {
            // SwiftUI creates Window scenes lazily — NSWindow doesn't exist yet at launch.
            // Retry until SwiftUI creates it (typically ~1-2s).
            func tryOpen(_ attempt: Int = 0) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let window = NSApp.windows.first(where: { $0.title == "VPN Fix" }) {
                        window.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                        AppLogger.shared.info("Dashboard opened on launch (attempt \(attempt + 1))")
                    } else if attempt < 10 {
                        tryOpen(attempt + 1)
                    } else {
                        AppLogger.shared.warn("Dashboard window not found after 10 attempts")
                    }
                }
            }
            tryOpen()
        }
    }

    private func checkForPhase1Migration() {
        let prefs = AppPreferences.shared
        guard !prefs.hasOfferedMigration else {
            AppLogger.shared.debug("Phase 1 migration already offered, skipping check")
            return
        }

        AppLogger.shared.debug("Scanning for Phase 1 artifacts...")
        let phase1Artifacts = [
            "/Library/LaunchDaemons/com.vpnmonitor.plist",
            NSHomeDirectory() + "/vpn-monitor.sh",
            NSHomeDirectory() + "/fix-vpn-disconnect.sh"
        ]

        let existingArtifacts = phase1Artifacts.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingArtifacts.isEmpty else {
            AppLogger.shared.debug("No Phase 1 artifacts found")
            prefs.hasOfferedMigration = true
            return
        }

        AppLogger.shared.info("Phase 1 artifacts found: \(existingArtifacts.joined(separator: ", "))")
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Previous Installation Detected"
            alert.informativeText = "Found Phase 1 VPN Fix files. Remove old installation?\n\nFiles found:\n" +
                existingArtifacts.map { "  \u{2022} \($0)" }.joined(separator: "\n")
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Later")

            AppLogger.shared.info("Showing Phase 1 migration dialog to user")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                AppLogger.shared.info("User chose to remove Phase 1 artifacts")
                self.removePhase1ArtifactsWithAdmin(existingArtifacts)
                prefs.hasOfferedMigration = true
            } else {
                AppLogger.shared.info("User deferred Phase 1 artifact removal")
            }
        }
    }

    private func removePhase1ArtifactsWithAdmin(_ artifacts: [String]) {
        AppLogger.shared.info("Starting Phase 1 artifact removal (\(artifacts.count) files)...")
        var commands: [String] = []

        for artifact in artifacts {
            if artifact.hasSuffix(".plist") {
                commands.append("launchctl unload '\(artifact)' 2>/dev/null || true")
            }
            commands.append("rm -f '\(artifact)'")
        }

        // Also clean up temp files
        commands.append("rm -f /tmp/vpn-was-connected")

        let fullCommand = commands.joined(separator: " && ")
        let escapedCommand = fullCommand.replacingOccurrences(of: "'", with: "'\\''")
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"

        guard let appleScript = NSAppleScript(source: script) else {
            AppLogger.shared.error("Failed to create AppleScript for Phase 1 removal")
            return
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error {
            AppLogger.shared.error("Failed to remove Phase 1 artifacts: \(error)")
        } else {
            AppLogger.shared.info("Phase 1 artifacts removed successfully")
        }
    }
}
