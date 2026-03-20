import SwiftUI

struct VPNClientCard: View {
    let client: VPNClientStatus
    let activeIssues: [VPNIssue]
    let dismissedCount: Int
    let isFixing: Bool
    let showDismissed: Bool
    let onFix: () -> Void
    let onFixIssue: (VPNIssue) -> Void
    let onDismiss: (VPNIssue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: client.clientType.sfSymbol)
                    .font(.system(size: 22))
                    .foregroundStyle(headerColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(client.clientType.displayName)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 7, height: 7)
                        Text(client.connectionState.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !activeIssues.isEmpty {
                    Text("\(activeIssues.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(headerColor, in: Circle())
                }

                if !activeIssues.isEmpty {
                    Button {
                        onFix()
                    } label: {
                        if isFixing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 60, height: 24)
                        } else {
                            Label("Fix All", systemImage: "wrench.and.screwdriver")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    .disabled(isFixing)
                }
            }
            .padding(12)

            // Issues list
            if !activeIssues.isEmpty {
                Divider()

                VStack(spacing: 0) {
                    ForEach(activeIssues) { issue in
                        IssueRow(
                            issue: issue,
                            isFixing: isFixing,
                            onFix: { onFixIssue(issue) },
                            onDismiss: { onDismiss(issue) }
                        )

                        if issue.id != activeIssues.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }

            // Dismissed indicator
            if dismissedCount > 0 && !showDismissed {
                Divider()
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("\(dismissedCount) dismissed issue\(dismissedCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // No issues state
            if activeIssues.isEmpty && dismissedCount == 0 {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("No issues detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(headerColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var headerColor: Color {
        if !activeIssues.isEmpty { return .orange }
        switch client.connectionState {
        case .connected: return .green
        case .disconnected: return .gray
        case .fixing: return .orange
        case .unknown: return .gray
        }
    }

    private var stateColor: Color {
        switch client.connectionState {
        case .connected: return .green
        case .disconnected: return .red
        case .fixing: return .orange
        case .unknown: return .gray
        }
    }
}

// MARK: - Issue Row

private struct IssueRow: View {
    let issue: VPNIssue
    let isFixing: Bool
    let onFix: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SeverityBadge(severity: issue.severity)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.description)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(issue.type.fixDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    onFix()
                } label: {
                    Label("Fix", systemImage: "wrench")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.mini)
                .disabled(isFixing)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Dismiss this issue")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
