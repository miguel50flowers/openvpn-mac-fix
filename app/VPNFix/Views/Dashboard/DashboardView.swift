import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NetworkStatusBanner(viewModel: viewModel)

            switch viewModel.viewState {
            case .loading:
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning for VPN clients...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

            case .error(let message):
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text("Connection Error")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        viewModel.scan()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding()
                Spacer()

            case .empty:
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("No VPN Clients Detected")
                        .font(.headline)
                    Text("Connect to a VPN and this dashboard will show detected clients and any network issues.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                }
                Spacer()

            case .loaded:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VPNClientSection(viewModel: viewModel)
                        NetworkDiagnosticsSection(viewModel: viewModel)
                    }
                    .padding()
                }
            }

            Divider()
            BottomToolbar(viewModel: viewModel)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
