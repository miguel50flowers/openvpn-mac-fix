import SwiftUI
import ServiceManagement

@main
struct VPNFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vpnStatus = VPNStatusViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: vpnStatus)
        } label: {
            Label(vpnStatus.state.label, systemImage: vpnStatus.state.sfSymbol)
                .symbolRenderingMode(.hierarchical)
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
        registerHelperIfNeeded()
        checkForPhase1Migration()
    }

    private func registerHelperIfNeeded() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.miguel50flowers.VPNFix.helper.plist")
            if service.status != .enabled {
                do {
                    try service.register()
                    NSLog("[VPNFix] Helper daemon registered successfully")
                } catch {
                    NSLog("[VPNFix] Failed to register helper daemon: \(error.localizedDescription)")
                }
            }
        }
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
                existingArtifacts.map { "  • \($0)" }.joined(separator: "\n")
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Keep Both")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                XPCClient.shared.removePhase1Artifacts { success, message in
                    if success {
                        prefs.hasOfferedMigration = true
                        NSLog("[VPNFix] Phase 1 artifacts removed: \(message)")
                    } else {
                        NSLog("[VPNFix] Failed to remove Phase 1 artifacts: \(message)")
                    }
                }
            case .alertSecondButtonReturn:
                prefs.hasOfferedMigration = true
            default:
                break
            }
        }
    }
}
