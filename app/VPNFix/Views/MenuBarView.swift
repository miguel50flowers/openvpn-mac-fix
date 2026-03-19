import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: VPNStatusViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status header
            Label("VPN: \(viewModel.state.label)", systemImage: viewModel.state.sfSymbol)
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            Divider()

            // Fix Now button
            Button {
                viewModel.runFix()
            } label: {
                Label("Fix Now", systemImage: "wrench.and.screwdriver")
            }
            .disabled(viewModel.state == .fixing)
            .keyboardShortcut("f")

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
                SparkleUpdater.shared.checkForUpdates()
            } label: {
                Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            // Helper status
            HStack {
                Circle()
                    .fill(viewModel.helperConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(viewModel.helperConnected ? "Helper Active" : "Helper Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            Divider()

            Button("Quit VPN Fix") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .frame(width: 240)
        .padding(.vertical, 4)
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
