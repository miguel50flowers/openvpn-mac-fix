import SwiftUI

struct OnboardingHowItWorksStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How It Works")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("VPN Fix runs in your menu bar and watches for network problems.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                FeatureCard(
                    symbol: "magnifyingglass",
                    color: .blue,
                    title: "Detect",
                    description: "Scans for stale routes, DNS leaks, and orphaned interfaces left behind by VPNs."
                )

                FeatureCard(
                    symbol: "stethoscope",
                    color: .green,
                    title: "Diagnose",
                    description: "Checks DNS servers, gateways, firewall rules, and proxy settings in real time."
                )

                FeatureCard(
                    symbol: "wrench.and.screwdriver",
                    color: .orange,
                    title: "Fix",
                    description: "Applies targeted repairs automatically or on-demand with a single click."
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

private struct FeatureCard: View {
    let symbol: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
