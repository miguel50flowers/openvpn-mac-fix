import SwiftUI

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
            syncLaunchAtLoginToggle()
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Enable VPN monitoring", isOn: $prefs.monitoringEnabled)

            Toggle("Launch at login", isOn: Binding(
                get: { prefs.launchAtLogin },
                set: { newValue in
                    prefs.launchAtLogin = newValue
                    setLaunchAtLogin(newValue)
                }
            ))

            Toggle("Show in Dock", isOn: Binding(
                get: { prefs.showDockIcon },
                set: { newValue in
                    prefs.showDockIcon = newValue
                    NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                }
            ))

            Picker("Update Check Frequency", selection: Binding(
                get: { prefs.updateCheckFrequency },
                set: { newValue in
                    prefs.updateCheckFrequency = newValue
                    SparkleUpdater.shared.applyCheckFrequency(newValue)
                }
            )) {
                Text("Automatic").tag("automatic")
                Text("Daily").tag("daily")
                Text("Weekly").tag("weekly")
                Text("Monthly").tag("monthly")
                Text("Manual").tag("manual")
            }

            LabeledContent("Helper Status") {
                HStack {
                    Circle()
                        .fill(helperActive ? .green : .orange)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(helperStatus)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Helper status: \(helperStatus)")
                .accessibilityValue(helperActive ? "Active" : "Inactive")
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

            Link("\u{00A9} 2026 maecly.com", destination: URL(string: "https://www.maecly.com/")!)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private static let launchAgentLabel = "com.miguel50flowers.VPNFix"

    private static var launchAgentPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(launchAgentLabel).plist"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let plistPath = Self.launchAgentPath

        if enabled {
            let appPath = Bundle.main.bundlePath

            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(Self.launchAgentLabel)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/bin/open</string>
                    <string>-a</string>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """

            do {
                let dirPath = (plistPath as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
                try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
                // Set permissions to 644
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: plistPath)
                AppLogger.shared.info("Launch at login enabled — wrote \(plistPath)")
            } catch {
                AppLogger.shared.error("Failed to enable launch at login: \(error)")
            }
        } else {
            do {
                if FileManager.default.fileExists(atPath: plistPath) {
                    try FileManager.default.removeItem(atPath: plistPath)
                }
                AppLogger.shared.info("Launch at login disabled — removed \(plistPath)")
            } catch {
                AppLogger.shared.error("Failed to disable launch at login: \(error)")
            }
        }
    }

    private func syncLaunchAtLoginToggle() {
        let exists = FileManager.default.fileExists(atPath: Self.launchAgentPath)
        if prefs.launchAtLogin != exists {
            prefs.launchAtLogin = exists
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
