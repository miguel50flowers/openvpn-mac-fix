import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var helperStatus: String = "Checking..."

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            notificationsTab
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "wrench")
                }
        }
        .frame(width: 450, height: 300)
        .onAppear {
            updateHelperStatus()
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Enable VPN monitoring", isOn: $prefs.monitoringEnabled)

            Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                .onChange(of: prefs.launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }

            LabeledContent("Helper Status") {
                HStack {
                    Circle()
                        .fill(helperStatus == "Enabled" ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(helperStatus)
                }
            }

            Button("Reinstall Helper") {
                reinstallHelper()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Notifications

    private var notificationsTab: some View {
        Form {
            Toggle("Notify on VPN connect", isOn: $prefs.notifyOnConnect)
            Toggle("Notify on VPN disconnect", isOn: $prefs.notifyOnDisconnect)
            Toggle("Notify when fix is applied", isOn: $prefs.notifyOnFix)
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Picker("Log Level", selection: $prefs.logLevel) {
                Text("Debug").tag("DEBUG")
                Text("Info").tag("INFO")
                Text("Warning").tag("WARN")
                Text("Error").tag("ERROR")
            }

            LabeledContent("Version") {
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
            }

            LabeledContent("Build") {
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.loginItem(identifier: XPCConstants.appBundleID)
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                NSLog("[VPNFix] Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    private func updateHelperStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.miguel50flowers.VPNFix.helper.plist")
            switch service.status {
            case .enabled: helperStatus = "Enabled"
            case .requiresApproval: helperStatus = "Requires Approval"
            case .notRegistered: helperStatus = "Not Registered"
            case .notFound: helperStatus = "Not Found"
            @unknown default: helperStatus = "Unknown"
            }
        }
    }

    private func reinstallHelper() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.miguel50flowers.VPNFix.helper.plist")
            do {
                try service.unregister()
            } catch {
                // Ignore unregister errors
            }
            do {
                try service.register()
                helperStatus = "Enabled"
            } catch {
                helperStatus = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
