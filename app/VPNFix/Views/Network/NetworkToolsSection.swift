import SwiftUI

struct NetworkToolsSection: View {
    @State private var runningAction: String?
    @State private var lastResult: (action: String, success: Bool, message: String)?

    private let tools: [(action: String, label: String, icon: String, tint: Color)] = [
        ("flushDNS", "Flush DNS", "server.rack", .blue),
        ("renewDHCP", "Renew DHCP", "arrow.triangle.2.circlepath", .green),
        ("resetWiFi", "Reset Wi-Fi", "wifi", .orange),
        ("resetInterface", "Reset Interface", "arrow.clockwise.circle", .purple),
        ("flushARP", "Flush ARP", "tablecells", .teal),
        ("toggleIPv6", "Reset IPv6", "6.circle", .indigo),
        ("fixMTU", "Fix MTU", "ruler", .brown),
        ("restartMDNS", "Restart mDNS", "bonjour", .pink),
        ("speedTest", "Speed Test", "gauge.with.needle", .cyan),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Tools")
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                ForEach(tools, id: \.action) { tool in
                    Button {
                        runRepair(tool.action)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tool.icon)
                                .font(.title3)
                                .frame(height: 24)
                            Text(tool.label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tool.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(tool.tint.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(runningAction != nil)
                    .overlay {
                        if runningAction == tool.action {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
            }

            // Fix Everything + Reset Network Prefs (full-width, separate)
            HStack(spacing: 10) {
                Button {
                    runRepair("fixEverything")
                } label: {
                    Label("Fix Everything", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .disabled(runningAction != nil)

                Button {
                    runRepair("resetNetworkPrefs")
                } label: {
                    Label("Reset Network Prefs", systemImage: "exclamationmark.triangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
                .disabled(runningAction != nil)
            }

            // Result banner
            if let result = lastResult {
                HStack(spacing: 6) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (result.success ? Color.green : Color.red).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .transition(.opacity)
            }
        }
    }

    private func runRepair(_ action: String) {
        runningAction = action
        lastResult = nil
        XPCClient.shared.runNetworkRepair(action) { success, message in
            DispatchQueue.main.async {
                withAnimation {
                    lastResult = (action, success, message)
                    runningAction = nil
                }
                // Auto-clear result after 8 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    if lastResult?.action == action {
                        withAnimation { lastResult = nil }
                    }
                }
            }
        }
    }
}
