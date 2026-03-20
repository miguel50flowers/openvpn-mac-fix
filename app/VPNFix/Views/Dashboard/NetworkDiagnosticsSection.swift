import SwiftUI

struct NetworkDiagnosticsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                if let diag = viewModel.diagnostics {
                    VStack(spacing: 1) {
                        DiagnosticRow(
                            label: "DNS Servers",
                            value: diag.dnsServers.isEmpty ? "None" : diag.dnsServers.joined(separator: ", "),
                            systemImage: "server.rack",
                            status: diag.dnsServers.isEmpty ? .warning : .ok
                        )

                        DiagnosticRow(
                            label: "Default Gateway",
                            value: diag.defaultGateway ?? "None",
                            systemImage: "arrow.triangle.branch",
                            status: diag.defaultGateway == nil ? .warning : .ok
                        )

                        DiagnosticRow(
                            label: "Active Interfaces",
                            value: diag.activeInterfaces.map(\.name).joined(separator: ", "),
                            systemImage: "network",
                            status: .ok
                        )

                        DiagnosticRow(
                            label: "Public IP",
                            value: diag.publicIP ?? "Unavailable",
                            systemImage: "globe",
                            status: diag.publicIP == nil ? .neutral : .ok
                        )

                        DiagnosticRow(
                            label: "PF Rules",
                            value: diag.pfRulesActive ? "Active" : "Inactive",
                            systemImage: "flame",
                            status: diag.pfRulesActive ? .warning : .ok
                        )

                        DiagnosticRow(
                            label: "Proxy Settings",
                            value: diag.proxyConfigured ? "Configured" : "None",
                            systemImage: "arrow.triangle.swap",
                            status: diag.proxyConfigured ? .warning : .ok
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading diagnostics...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .padding(.top, 8)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Network Status")
                        .font(.title3.weight(.semibold))
                    Text("General network configuration (not VPN-specific)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
