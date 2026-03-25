import SwiftUI
import AppKit

struct AboutView: View {
    @State private var helperVersion = "..."

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }

            Text("VPN Fix")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The macOS Network & VPN Repair Tool")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

            HStack(spacing: 16) {
                LabeledValue(label: "App Version", value: "\(version) (\(build))")
                LabeledValue(label: "Helper", value: helperVersion)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Link("\u{00A9} 2026 maecly.com", destination: URL(string: "https://www.maecly.com/")!)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            XPCClient.shared.getVersion { v in
                DispatchQueue.main.async { helperVersion = v }
            }
        }
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospaced())
        }
    }
}
