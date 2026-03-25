import SwiftUI

struct OnboardingReadyStep: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var notificationsEnabled = false
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .frame(width: 80, height: 80)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            Text("You're All Set")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("VPN Fix will monitor your network from the menu bar\nand notify you when issues are detected.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Quick preferences
            VStack(spacing: 0) {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onChange(of: notificationsEnabled) { enabled in
                        if enabled {
                            NotificationService.shared.requestPermission()
                        }
                        prefs.notifyOnConnect = enabled
                        prefs.notifyOnDisconnect = enabled
                        prefs.notifyOnFix = enabled
                    }

                Divider().padding(.leading, 16)

                Toggle("Launch at login", isOn: Binding(
                    get: { prefs.launchAtLogin },
                    set: { newValue in
                        prefs.launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                    }
                ))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .frame(maxWidth: 320)

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Start Using VPN Fix")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 60)
        .onAppear {
            notificationsEnabled = prefs.notifyOnConnect
        }
    }

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
            } catch {
                AppLogger.shared.error("Failed to enable launch at login: \(error)")
            }
        } else {
            try? FileManager.default.removeItem(atPath: plistPath)
        }
    }
}
