import SwiftUI

struct VPNClientsDetailView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") { viewModel.scan() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("No VPN Clients Detected")
                        .font(.headline)
                    Text("Connect to a VPN to see detected clients here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VPNClientSection(viewModel: viewModel)
                    }
                    .padding()
                }
            }
        }
    }
}
