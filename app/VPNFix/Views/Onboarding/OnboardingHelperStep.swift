import SwiftUI

struct OnboardingHelperStep: View {
    @State private var helperState: HelperState = .checking

    private enum HelperState {
        case checking, notInstalled, installing, installed, failed
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .frame(width: 80, height: 80)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            Text("Install Helper")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("VPN Fix needs a small background service to monitor\nand repair network settings with the right permissions.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.secondary)
                    Text("Runs as a system daemon to fix routes and DNS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "key")
                        .foregroundStyle(.secondary)
                    Text("Requires your admin password once during setup")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            // Status + action
            switch helperState {
            case .checking:
                ProgressView()
                    .onAppear { checkHelperStatus() }

            case .notInstalled:
                Button {
                    installHelper()
                } label: {
                    Label("Install Helper", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .installing:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Installing...")
                        .foregroundStyle(.secondary)
                }

            case .installed:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text("Helper installed and active")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

            case .failed:
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Installation failed or was cancelled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button("Try Again") {
                        installHelper()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            Spacer()

            Text("You can reinstall or remove the helper later in Settings > General.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 60)
    }

    private func checkHelperStatus() {
        let status = HelperInstaller.shared.checkStatus()
        helperState = status.isActive ? .installed : .notInstalled
    }

    private func installHelper() {
        helperState = .installing
        DispatchQueue.global(qos: .userInitiated).async {
            HelperInstaller.shared.install()
            let status = HelperInstaller.shared.checkStatus()
            DispatchQueue.main.async {
                helperState = status.isActive ? .installed : .failed
            }
        }
    }
}
