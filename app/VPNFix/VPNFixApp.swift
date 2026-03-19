import SwiftUI

@main
struct VPNFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vpnStatus = VPNStatusViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: vpnStatus)
        } label: {
            Image(systemName: vpnStatus.state.sfSymbol)
        }

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
        notificationService.requestPermission()
        HelperInstaller.shared.installIfNeeded()
        checkForPhase1Migration()
    }

    private func checkForPhase1Migration() {
        let prefs = AppPreferences.shared
        guard !prefs.hasOfferedMigration else { return }

        let phase1Artifacts = [
            "/Library/LaunchDaemons/com.vpnmonitor.plist",
            NSHomeDirectory() + "/vpn-monitor.sh",
            NSHomeDirectory() + "/fix-vpn-disconnect.sh"
        ]

        let existingArtifacts = phase1Artifacts.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingArtifacts.isEmpty else {
            prefs.hasOfferedMigration = true
            return
        }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Previous Installation Detected"
            alert.informativeText = "Found Phase 1 VPN Fix files. Remove old installation?\n\nFiles found:\n" +
                existingArtifacts.map { "  \u{2022} \($0)" }.joined(separator: "\n")
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.removePhase1ArtifactsWithAdmin(existingArtifacts)
                prefs.hasOfferedMigration = true
            }
        }
    }

    private func removePhase1ArtifactsWithAdmin(_ artifacts: [String]) {
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

        guard let appleScript = NSAppleScript(source: script) else { return }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error {
            NSLog("[VPNFix] Failed to remove Phase 1 artifacts: \(error)")
        } else {
            NSLog("[VPNFix] Phase 1 artifacts removed successfully")
        }
    }
}
