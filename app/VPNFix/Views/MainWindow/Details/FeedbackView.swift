import SwiftUI
import AppKit

struct FeedbackView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Feedback & Support")
                .font(.title2)
                .fontWeight(.bold)

            Text("Help us improve VPN Fix by reporting bugs, suggesting features, or sharing your experience.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(spacing: 12) {
                Button {
                    let info = SystemInfoCollector.collect()
                    let url = GitHubIssueURLBuilder.feedbackURL(systemInfo: info)
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Send Feedback", systemImage: "envelope")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)

                Button {
                    let info = SystemInfoCollector.collect()
                    let logs = LogCollector.recentLines(count: 30)
                    let url = GitHubIssueURLBuilder.bugReportURL(systemInfo: info, recentLogs: logs)
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Report Issue", systemImage: "ladybug")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.large)
            }

            Text("Reports include device info and recent logs visible on GitHub.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(maxWidth: 300)

            HStack(spacing: 24) {
                Link(destination: URL(string: "https://github.com/miguel50flowers/openvpn-mac-fix")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://vpn-fix.maecly.com/")!) {
                    Label("Website", systemImage: "globe")
                }
            }
            .font(.subheadline)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
