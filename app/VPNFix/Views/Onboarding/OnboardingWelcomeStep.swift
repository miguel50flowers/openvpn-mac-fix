import SwiftUI
import AppKit

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }

            Text("Welcome to VPN Fix")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Automatically detects and repairs network issues\ncaused by VPN disconnections on macOS.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()

            Text("Supports 17+ VPN clients including OpenVPN, WireGuard, FortiClient, and more.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 60)
    }
}
