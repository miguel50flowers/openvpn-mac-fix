import SwiftUI

struct LogViewerView: View {
    @StateObject private var viewModel = LogViewModel()
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(viewModel.filteredLogLines.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(viewModel.filteredLogLines.count) log lines")

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button("Copy All") {
                    let allText = viewModel.filteredLogLines.map(\.raw).joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(allText, forType: .string)
                }
                .accessibilityHint("Copies all log lines to the clipboard")

                Button("Clear Logs") {
                    viewModel.clearLogs()
                }
                .accessibilityHint("Removes all log entries from the viewer")
            }
            .padding(8)

            Divider()

            // Log content
            if viewModel.filteredLogLines.isEmpty {
                Spacer()
                Text("No log entries yet")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(viewModel.filteredLogLines.enumerated()), id: \.offset) { index, line in
                                LogLineView(line: line)
                                    .id(index)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    }
                    .onChange(of: viewModel.filteredLogLines.count) { _ in
                        if autoScroll, let lastIndex = viewModel.filteredLogLines.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            viewModel.startTailing()
        }
        .onDisappear {
            viewModel.stopTailing()
        }
    }
}

struct LogLineView: View {
    let line: LogLine

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let timestamp = line.timestamp {
                Text(timestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let level = line.level {
                Text(level)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(colorForLevel(level))
                    .frame(width: 50, alignment: .leading)
            }

            Text(line.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.level ?? "LOG"): \(line.message)")
    }

    private func colorForLevel(_ level: String) -> Color {
        switch level.uppercased() {
        case "ERROR": return .red
        case "WARN", "WARNING": return .orange
        case "INFO": return .primary
        case "DEBUG": return .secondary
        default: return .primary
        }
    }
}
