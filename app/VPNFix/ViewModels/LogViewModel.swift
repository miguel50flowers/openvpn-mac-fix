import Foundation

/// Parsed log line.
struct LogLine: Identifiable {
    let id = UUID()
    let timestamp: String?
    let level: String?
    let message: String
    let raw: String
}

/// Tails the VPN monitor log file and parses entries.
final class LogViewModel: ObservableObject {
    @Published var logLines: [LogLine] = []

    private let logPath = "/tmp/vpn-monitor.log"
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?

    func startTailing() {
        loadExistingContent()
        watchForChanges()
    }

    func stopTailing() {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
    }

    func clearLogs() {
        logLines.removeAll()
        // Also truncate the file
        if FileManager.default.isWritableFile(atPath: logPath) {
            try? "".write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Private

    private func loadExistingContent() {
        guard let data = FileManager.default.contents(atPath: logPath),
              let content = String(data: data, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { parseLine($0) }

        DispatchQueue.main.async {
            self.logLines = lines
        }
    }

    private func watchForChanges() {
        let fd = open(logPath, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }

        // Seek to end to only get new content
        lseek(fd, 0, SEEK_END)

        fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            guard let self else { return }
            let data = self.fileHandle?.availableData ?? Data()
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            let newLines = text.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { self.parseLine($0) }

            DispatchQueue.main.async {
                self.logLines.append(contentsOf: newLines)
                // Keep a reasonable buffer
                if self.logLines.count > 5000 {
                    self.logLines.removeFirst(self.logLines.count - 5000)
                }
            }
        }

        source?.setCancelHandler {
            close(fd)
        }

        source?.resume()
    }

    /// Parse a log line like: "[2026-03-17 10:30:45] [INFO] Some message"
    private func parseLine(_ raw: String) -> LogLine {
        // Pattern: [timestamp] [LEVEL] message
        let pattern = #"^\[([^\]]+)\]\s*\[([^\]]+)\]\s*(.*)$"#
        if let match = raw.range(of: pattern, options: .regularExpression) {
            let groups = raw.captureGroups(pattern: pattern)
            if groups.count >= 3 {
                return LogLine(timestamp: groups[0], level: groups[1], message: groups[2], raw: raw)
            }
        }
        return LogLine(timestamp: nil, level: nil, message: raw, raw: raw)
    }
}

// MARK: - Regex Helper

private extension String {
    func captureGroups(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else {
            return []
        }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: self) else { return nil }
            return String(self[range])
        }
    }
}
