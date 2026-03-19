import SwiftUI

struct LogViewerView: View {
    @StateObject private var viewModel = LogViewModel()
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(viewModel.logLines.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button("Copy All") {
                    let allText = viewModel.logLines.map(\.raw).joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(allText, forType: .string)
                }

                Button("Clear Logs") {
                    viewModel.clearLogs()
                }
            }
            .padding(8)

            Divider()

            // Log content
            if viewModel.logLines.isEmpty {
                Spacer()
                Text("No log entries yet")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(viewModel.logLines.enumerated()), id: \.offset) { index, line in
                                LogLineView(line: line)
                                    .id(index)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    }
                    .onChange(of: viewModel.logLines.count) { _ in
                        if autoScroll, let lastIndex = viewModel.logLines.indices.last {
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
