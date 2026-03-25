import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var helperVersion = "Checking..."
    @State private var cliBinaryExists = false

    private var cliBinaryPath: String {
        let appPath = Bundle.main.bundlePath
        return (appPath as NSString).deletingLastPathComponent + "/vpnfix"
    }

    var body: some View {
        Form {
            Section("Logging") {
                Picker("Log Level", selection: $prefs.logLevel) {
                    Text("All").tag("ALL")
                    Text("Debug").tag("DEBUG")
                    Text("Info").tag("INFO")
                    Text("Warning").tag("WARN")
                    Text("Error").tag("ERROR")
                }
            }

            Section("CLI Tool") {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cliBinaryExists ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(cliBinaryExists ? "Available" : "Not found")
                    }
                }

                if cliBinaryExists {
                    LabeledContent("Path") {
                        HStack(spacing: 6) {
                            Text(cliBinaryPath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(cliBinaryPath, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .help("Copy path to clipboard")
                        }
                    }
                }

                DisclosureGroup("Usage") {
                    Text("""
                    vpnfix status          Show detected VPN clients
                    vpnfix diagnose        Network diagnostics
                    vpnfix fix --all       Fix all detected issues
                    vpnfix fix <type>      Fix a specific VPN client
                    vpnfix version         Show helper version
                    """)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                }
            }

            Section("Documentation") {
                LabeledContent("Helper Version") {
                    Text(helperVersion)
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/miguel50flowers/openvpn-mac-fix")!) {
                    Label("GitHub Repository", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/miguel50flowers/openvpn-mac-fix/issues")!) {
                    Label("Report an Issue", systemImage: "ladybug")
                }

                Link(destination: URL(string: "https://vpn-fix.maecly.com/")!) {
                    Label("Website", systemImage: "globe")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            cliBinaryExists = FileManager.default.fileExists(atPath: cliBinaryPath)
            fetchHelperVersion()
        }
    }

    private func fetchHelperVersion() {
        XPCClient.shared.getVersion { version in
            DispatchQueue.main.async {
                helperVersion = version
            }
        }
    }
}
