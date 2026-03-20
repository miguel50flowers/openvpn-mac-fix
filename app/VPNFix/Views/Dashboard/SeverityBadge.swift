import SwiftUI

struct SeverityBadge: View {
    let severity: VPNIssue.Severity

    var body: some View {
        Text(severity.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor, in: Capsule())
    }

    private var backgroundColor: Color {
        switch severity {
        case .critical: return .red.opacity(0.15)
        case .high: return .orange.opacity(0.15)
        case .medium: return .yellow.opacity(0.15)
        case .low: return .gray.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .orange
        case .low: return .secondary
        }
    }
}
