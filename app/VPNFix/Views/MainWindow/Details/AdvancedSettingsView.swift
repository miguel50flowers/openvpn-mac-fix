import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var cliState: CLIState = .checking
    @State private var cliInstalledPath: String?

    private let installPath = "/usr/local/bin/vpnfix"

    private enum CLIState {
        case checking, notInstalled, installing, installed, failed(String)
    }

    private var bundledCLIPath: String? {
        Bundle.main.path(forAuxiliaryExecutable: "vpnfix")
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
                switch cliState {
                case .checking:
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Checking...").foregroundStyle(.secondary)
                    }

                case .notInstalled:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(.orange).frame(width: 8, height: 8)
                            Text("Not Installed")
                        }

                        Text("Install the `vpnfix` command-line tool to manage VPN fixes from Terminal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            installCLI()
                        } label: {
                            Label("Install CLI to /usr/local/bin", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Text("Requires admin password. Copies the binary to /usr/local/bin/vpnfix.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                case .installing:
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Installing...").foregroundStyle(.secondary)
                    }

                case .installed:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Installed")
                        }

                        if let path = cliInstalledPath {
                            LabeledContent("Path") {
                                HStack(spacing: 6) {
                                    Text(path)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(path, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc").font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .help("Copy path to clipboard")
                                }
                            }
                        }

                        Button("Uninstall CLI") {
                            uninstallCLI()
                        }
                        .foregroundStyle(.red)
                        .controlSize(.small)
                    }

                case .failed(let msg):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text("Installation failed")
                        }
                        Text(msg).font(.caption).foregroundStyle(.secondary)
                        Button("Try Again") { installCLI() }
                            .controlSize(.small)
                    }
                }

                DisclosureGroup("Usage") {
                    Text("""
                    vpnfix status            Show detected VPN clients
                    vpnfix diagnose          Network diagnostics
                    vpnfix fix --all         Fix all detected issues
                    vpnfix fix <type>        Fix a specific VPN client
                    vpnfix repair <action>   Run a network repair
                    vpnfix speedtest         Run speed/quality test
                    vpnfix version           Show helper version
                    """)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { checkCLIStatus() }
    }

    private func checkCLIStatus() {
        if FileManager.default.fileExists(atPath: installPath) {
            cliState = .installed
            cliInstalledPath = installPath
        } else {
            cliState = .notInstalled
        }
    }

    private func installCLI() {
        guard let source = bundledCLIPath else {
            cliState = .failed("CLI binary not found in app bundle")
            return
        }

        cliState = .installing
        DispatchQueue.global(qos: .userInitiated).async {
            let escaped = source.replacingOccurrences(of: "'", with: "'\\''")
            let command = "mkdir -p /usr/local/bin && cp '\(escaped)' '\(installPath)' && chmod 755 '\(installPath)'"
            let scriptSource = "do shell script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

            guard let script = NSAppleScript(source: scriptSource) else {
                DispatchQueue.main.async { cliState = .failed("Failed to create install script") }
                return
            }

            var error: NSDictionary?
            script.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if error != nil {
                    cliState = .failed("Cancelled or permission denied")
                } else {
                    cliState = .installed
                    cliInstalledPath = installPath
                    AppLogger.shared.info("CLI installed to \(installPath)")
                }
            }
        }
    }

    private func uninstallCLI() {
        let command = "rm -f '\(installPath)'"
        let scriptSource = "do shell script \"\(command)\" with administrator privileges"
        guard let script = NSAppleScript(source: scriptSource) else { return }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        if error == nil {
            cliState = .notInstalled
            cliInstalledPath = nil
            AppLogger.shared.info("CLI uninstalled from \(installPath)")
        }
    }
}
