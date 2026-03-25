import SwiftUI

struct ManageVPNsSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject private var prefs = AppPreferences.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAddCustomSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage VPN Clients")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            if viewModel.clients.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shield.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No VPN clients detected")
                        .foregroundStyle(.secondary)
                    Text("Run a scan to detect installed VPN clients.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Detected Clients") {
                        ForEach(viewModel.clients) { client in
                            ClientVisibilityRow(client: client, viewModel: viewModel)
                        }
                    }

                    if !prefs.customVPNEntries.isEmpty {
                        Section("Custom Clients") {
                            ForEach(prefs.customVPNEntries) { entry in
                                HStack(spacing: 10) {
                                    Image(systemName: "puzzlepiece.extension")
                                        .font(.title3)
                                        .foregroundStyle(.purple)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.displayName)
                                            .font(.subheadline)
                                        Text(entry.appPath)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Button {
                                        prefs.removeCustomVPN(id: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove custom VPN entry")
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button {
                    showAddCustomSheet = true
                } label: {
                    Label("Add Custom VPN", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if viewModel.hiddenClientCount > 0 {
                    Button("Show All") {
                        viewModel.unhideAllClients()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(width: 420, height: 440)
        .sheet(isPresented: $showAddCustomSheet) {
            AddCustomVPNSheet()
        }
    }
}

private struct ClientVisibilityRow: View {
    let client: VPNClientStatus
    @ObservedObject var viewModel: DashboardViewModel

    private var isHidden: Bool {
        AppPreferences.shared.isClientHidden(client.clientType.rawValue)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: client.clientType.sfSymbol)
                .font(.title3)
                .foregroundStyle(isHidden ? Color.secondary : Color.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.clientType.displayName)
                    .font(.subheadline)
                    .foregroundColor(isHidden ? .secondary : .primary)
                Text(client.connectionState.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { visible in
                    if visible {
                        viewModel.unhideClient(client.clientType)
                    } else {
                        viewModel.hideClient(client.clientType)
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
