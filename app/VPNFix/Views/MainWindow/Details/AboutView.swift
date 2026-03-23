import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text("VPN Fix")
                .font(.title2)
                .fontWeight(.bold)

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Detects and fixes network issues after OpenVPN disconnects on macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Link("Website", destination: URL(string: "https://vpn-fix.maecly.com/")!)
                .font(.caption)

            Link("GitHub Repository", destination: URL(string: "https://github.com/miguel50flowers/openvpn-mac-fix")!)
                .font(.caption)

            Spacer()

            Link("\u{00A9} 2026 maecly.com", destination: URL(string: "https://www.maecly.com/")!)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
