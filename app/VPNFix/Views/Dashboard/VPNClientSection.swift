import SwiftUI

struct VPNClientSection: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected VPN Clients")
                    .font(.title3.weight(.semibold))

                Spacer()

                if viewModel.hasDismissedIssues {
                    Toggle("Show dismissed", isOn: $viewModel.showDismissed)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                if viewModel.hasDismissedIssues && viewModel.showDismissed {
                    Button("Undismiss All") {
                        viewModel.undismissAll()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.clients.isEmpty {
                if viewModel.isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Scanning for VPN clients...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No VPN clients detected")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.clients) { client in
                        let active = viewModel.showDismissed
                            ? client.detectedIssues
                            : viewModel.activeIssues(for: client)
                        let dismissed = viewModel.dismissedIssueCount(for: client)

                        VPNClientCard(
                            client: client,
                            activeIssues: active,
                            dismissedCount: dismissed,
                            isFixing: viewModel.fixingClients.contains(client.clientType.rawValue),
                            showDismissed: viewModel.showDismissed,
                            onFix: { viewModel.fixClient(client.clientType) },
                            onFixIssue: { _ in viewModel.fixClient(client.clientType) },
                            onDismiss: { issue in
                                viewModel.dismissIssue(type: issue.type, client: client.clientType)
                            }
                        )
                    }
                }
            }
        }
    }
}
