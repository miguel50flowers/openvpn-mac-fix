import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @Environment(\.openWindow) private var openWindow
    @State private var helperStatus: String = "Checking..."
    @State private var helperActive: Bool = false

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

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
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

            Toggle("Show in Dock", isOn: $prefs.showDockIcon)
                .onChange(of: prefs.showDockIcon) { newValue in
                    NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                }

            Picker("Update Check Frequency", selection: $prefs.updateCheckFrequency) {
                Text("Automatic").tag("automatic")
                Text("Daily").tag("daily")
                Text("Weekly").tag("weekly")
                Text("Monthly").tag("monthly")
                Text("Manual").tag("manual")
            }
            .onChange(of: prefs.updateCheckFrequency) { newValue in
                SparkleUpdater.shared.applyCheckFrequency(newValue)
            }

            LabeledContent("Helper Status") {
                HStack {
                    Circle()
                        .fill(helperActive ? .green : .orange)
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

            Divider()

            Button("Send Test Notification") {
                NotificationService.shared.postTestNotification()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Picker("Log Level", selection: $prefs.logLevel) {
                Text("All").tag("ALL")
                Text("Debug").tag("DEBUG")
                Text("Info").tag("INFO")
                Text("Warning").tag("WARN")
                Text("Error").tag("ERROR")
            }

            Button("View Logs") {
                openWindow(id: "log-viewer")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text("VPN Fix")
                .font(.title2)
                .fontWeight(.bold)

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Detects and fixes network issues after OpenVPN disconnects on macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Link("GitHub Repository", destination: URL(string: "https://github.com/miguel50flowers/openvpn-mac-fix")!)
                .font(.caption)

            Spacer()

            Text("\u{00A9} 2025 miguel50flowers")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
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
                AppLogger.shared.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    private func updateHelperStatus() {
        let status = HelperInstaller.shared.checkStatus()
        helperActive = status.isActive
        helperStatus = status.label
    }

    private func reinstallHelper() {
        helperStatus = "Reinstalling..."
        DispatchQueue.global(qos: .userInitiated).async {
            HelperInstaller.shared.reinstall()
            DispatchQueue.main.async {
                updateHelperStatus()
            }
        }
    }
}
