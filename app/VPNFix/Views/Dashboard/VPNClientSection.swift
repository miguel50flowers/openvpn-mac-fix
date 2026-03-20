import SwiftUI

struct VPNClientSection: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected VPN Clients")
                .font(.title3.weight(.semibold))

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.clients) { client in
                        VPNClientCard(
                            client: client,
                            isFixing: viewModel.fixingClients.contains(client.clientType.rawValue),
                            onFix: { viewModel.fixClient(client.clientType) }
                        )
                    }
                }
            }
        }
    }
}
