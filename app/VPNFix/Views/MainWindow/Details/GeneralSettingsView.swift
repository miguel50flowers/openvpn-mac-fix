import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var helperStatus: String = "Checking..."
    @State private var helperActive: Bool = false

    var body: some View {
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

            Toggle("Show Dashboard on launch", isOn: $prefs.showDashboardOnLaunch)

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

            Button("Check for Updates...") {
                SparkleUpdater.shared.checkForUpdates()
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
        .onAppear {
            updateHelperStatus()
            syncLaunchAtLoginToggle()
        }
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
