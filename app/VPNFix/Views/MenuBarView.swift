import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: VPNStatusViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status header
            Label(statusText, systemImage: viewModel.state.sfSymbol)
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .accessibilityLabel("VPN status: \(statusText)")

            Divider()

            // Open Dashboard
            Button {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Dashboard", systemImage: "rectangle.3.group")
            }
            .keyboardShortcut("d")

            Divider()

            // Fix button
            Button {
                viewModel.runFix()
            } label: {
                Label(fixButtonLabel, systemImage: "wrench.and.screwdriver")
            }
            .disabled(viewModel.state == .fixing)
            .keyboardShortcut("f")
            .accessibilityLabel(fixButtonLabel)
            .accessibilityHint("Applies fixes to all detected VPN issues")

            Divider()

            // Monitoring toggle
            Toggle(isOn: $viewModel.monitoringEnabled) {
                Label("Auto-Monitor", systemImage: "eye")
            }
            .toggleStyle(.automatic)

            Divider()

            // Log Viewer
            Button {
                openWindow(id: "log-viewer")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("View Logs", systemImage: "doc.text.magnifyingglass")
            }
            .keyboardShortcut("l")

            // Preferences
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Preferences...", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
            } else {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Preferences...", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
            }

            // Check for Updates
            Button {
                NSApp.activate(ignoringOtherApps: true)
                SparkleUpdater.shared.checkForUpdates()
            } label: {
                Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            // Helper status + issue count
            HStack {
                Circle()
                    .fill(viewModel.helperConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(viewModel.helperConnected ? "Helper Active" : "Helper Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if viewModel.clientsWithIssues > 0 {
                    Text("\(viewModel.clientsWithIssues) issue\(viewModel.clientsWithIssues == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                        .accessibilityLabel("\(viewModel.clientsWithIssues) \(viewModel.clientsWithIssues == 1 ? "issue" : "issues") detected")
                }
            }
            .padding(.horizontal, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Helper status: \(viewModel.helperConnected ? "Active" : "Offline")\(viewModel.clientsWithIssues > 0 ? ", \(viewModel.clientsWithIssues) \(viewModel.clientsWithIssues == 1 ? "issue" : "issues") detected" : "")")

            Divider()

            Button("Quit VPN Fix") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .frame(width: 240)
        .padding(.vertical, 4)
    }

    private var statusText: String {
        if viewModel.detectedClientCount > 0 {
            if viewModel.clientsWithIssues > 0 {
                return "\(viewModel.clientsWithIssues) Issue\(viewModel.clientsWithIssues == 1 ? "" : "s") Detected"
            }
            return "\(viewModel.detectedClientCount) VPN\(viewModel.detectedClientCount == 1 ? "" : "s") Active"
        }
        return "VPN: \(viewModel.state.label)"
    }

    private var fixButtonLabel: String {
        viewModel.clientsWithIssues > 1 ? "Fix All" : "Fix Now"
    }
}

// MARK: - VPNState UI Extensions

extension VPNState {
    var tintColor: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .red
        case .fixing: return .orange
        case .unknown: return .gray
        }
    }
}
