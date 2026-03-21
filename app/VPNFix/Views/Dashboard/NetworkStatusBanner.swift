import SwiftUI

struct NetworkStatusBanner: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.overallHealth.sfSymbol)
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.overallHealth.label)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    if let diagnostics = viewModel.diagnostics {
                        if let gateway = diagnostics.defaultGateway {
                            Label("Gateway: \(gateway)", systemImage: "arrow.triangle.branch")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Label("DNS: \(diagnostics.dnsServers.prefix(2).joined(separator: ", "))", systemImage: "server.rack")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }

            Spacer()

            if viewModel.activeVPNCount > 0 {
                Text("\(viewModel.activeVPNCount) VPN\(viewModel.activeVPNCount == 1 ? "" : "s") Active")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
                    .accessibilityLabel("\(viewModel.activeVPNCount) active VPN \(viewModel.activeVPNCount == 1 ? "connection" : "connections")")
            }

            if viewModel.totalIssueCount > 0 {
                Text("\(viewModel.totalIssueCount) Issue\(viewModel.totalIssueCount == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
                    .accessibilityLabel("\(viewModel.totalIssueCount) \(viewModel.totalIssueCount == 1 ? "issue" : "issues") detected")
            }
        }
        .padding()
        .background(viewModel.overallHealth.color.gradient)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Network health: \(viewModel.overallHealth.label)")
    }
}
