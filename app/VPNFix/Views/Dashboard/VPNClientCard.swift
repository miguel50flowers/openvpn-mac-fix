import SwiftUI

struct VPNClientCard: View {
    let client: VPNClientStatus
    let isFixing: Bool
    let onFix: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: client.clientType.sfSymbol)
                .font(.system(size: 28))
                .foregroundStyle(statusColor)
                .frame(height: 36)

            // Name
            Text(client.clientType.displayName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Issue count
            if client.hasIssues {
                Text("\(client.issueCount) issue\(client.issueCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1), in: Capsule())
            }

            // Fix button
            if client.hasIssues {
                Button {
                    onFix()
                } label: {
                    if isFixing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(height: 16)
                    } else {
                        Label("Fix", systemImage: "wrench.and.screwdriver")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .disabled(isFixing)
            }
        }
        .padding(12)
        .frame(minWidth: 140, minHeight: 140)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var statusColor: Color {
        if client.hasIssues { return .orange }
        switch client.connectionState {
        case .connected: return .green
        case .disconnected: return .red
        case .fixing: return .orange
        case .unknown: return .gray
        }
    }

    private var statusLabel: String {
        if client.hasIssues { return "Issues" }
        return client.connectionState.label
    }
}
