import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            NetworkStatusBanner(viewModel: viewModel)

            if case .loaded = viewModel.viewState {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NetworkDiagnosticsSection(viewModel: viewModel)
                        NetworkToolsSection()
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("Run a scan to see network diagnostics.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
