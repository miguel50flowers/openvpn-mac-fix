import SwiftUI

struct BottomToolbar: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        HStack {
            // Fix All button
            Button {
                viewModel.fixAll()
            } label: {
                if viewModel.isFixingAll {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Fixing...")
                    }
                } else {
                    Label("Fix All", systemImage: "wrench.and.screwdriver.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.totalIssueCount == 0 || viewModel.isFixingAll)

            // Scan button
            Button {
                viewModel.scan()
            } label: {
                if viewModel.isScanning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Scanning...")
                    }
                } else {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
            }
            .disabled(viewModel.isScanning)

            Spacer()

            // Last scan time
            if let lastScan = viewModel.lastScanTime {
                Text("Last scan: \(lastScan, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
