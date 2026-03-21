import SwiftUI

struct DiagnosticRow: View {
    let label: String
    let value: String
    let systemImage: String
    let status: Status

    enum Status {
        case ok, warning, neutral

        var color: Color {
            switch self {
            case .ok: return .green
            case .warning: return .orange
            case .neutral: return .gray
            }
        }
    }

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(status.color)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(label)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityValue("Status: \(statusLabel)")
    }

    private var statusLabel: String {
        switch status {
        case .ok: return "OK"
        case .warning: return "Warning"
        case .neutral: return "Neutral"
        }
    }
}
