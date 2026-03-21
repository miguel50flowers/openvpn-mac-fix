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
            .accessibilityLabel(viewModel.isFixingAll ? "Fixing all issues" : "Fix All")
            .accessibilityHint("Applies fixes for all detected VPN issues across all clients")
            .accessibilityValue(viewModel.totalIssueCount > 0 ? "\(viewModel.totalIssueCount) \(viewModel.totalIssueCount == 1 ? "issue" : "issues") to fix" : "No issues to fix")

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
            .accessibilityLabel(viewModel.isScanning ? "Scanning for issues" : "Scan")
            .accessibilityHint("Scans all VPN clients for network issues")

            Spacer()

            // Last scan time
            if let lastScan = viewModel.lastScanTime {
                Text("Last scan: \(lastScan, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Last scan was \(lastScan, style: .relative) ago")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
