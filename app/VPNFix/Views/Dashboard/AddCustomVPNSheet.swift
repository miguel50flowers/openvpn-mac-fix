import SwiftUI
import AppKit

struct AddCustomVPNSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var appPath = ""
    @State private var processName = ""
    @State private var interfaceType: CustomVPNEntry.InterfaceType = .utun

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Custom VPN")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            Form {
                Section("VPN Details") {
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        TextField("Application Path", text: $appPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") { browseForApp() }
                            .controlSize(.small)
                    }

                    TextField("Process Name", text: $processName)
                        .textFieldStyle(.roundedBorder)

                    Text("The process name is used to detect if this VPN is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Network Interface") {
                    Picker("Interface Type", selection: $interfaceType) {
                        ForEach(CustomVPNEntry.InterfaceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Select the tunnel interface type your VPN uses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Add VPN") {
                    addCustomVPN()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(displayName.isEmpty || processName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Select VPN Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            appPath = url.path
            if displayName.isEmpty {
                displayName = url.deletingPathExtension().lastPathComponent
            }
            if processName.isEmpty {
                if let bundle = Bundle(url: url),
                   let execName = bundle.executableURL?.lastPathComponent {
                    processName = execName
                }
            }
        }
    }

    private func addCustomVPN() {
        let entry = CustomVPNEntry(
            displayName: displayName,
            appPath: appPath,
            processName: processName,
            interfaceType: interfaceType
        )
        AppPreferences.shared.addCustomVPN(entry)
        syncCustomEntriesToHelper()
        dismiss()
    }

    private func syncCustomEntriesToHelper() {
        let entries = AppPreferences.shared.customVPNEntries
        guard let data = try? JSONEncoder().encode(entries),
              let json = String(data: data, encoding: .utf8) else { return }
        XPCClient.shared.setCustomVPNEntries(json) { _ in }
    }
}
