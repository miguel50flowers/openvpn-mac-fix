import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NetworkStatusBanner(viewModel: viewModel)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VPNClientSection(viewModel: viewModel)
                    NetworkDiagnosticsSection(viewModel: viewModel)
                }
                .padding()
            }

            Divider()
            BottomToolbar(viewModel: viewModel)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
