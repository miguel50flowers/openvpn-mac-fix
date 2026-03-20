import Foundation

/// Parsed log line.
struct LogLine: Identifiable {
    let id = UUID()
    let timestamp: String?
    let level: String?
    let message: String
    let raw: String
}

/// Tails both the app log and helper log, merging entries by timestamp.
final class LogViewModel: ObservableObject {
    @Published var logLines: [LogLine] = []

    var filteredLogLines: [LogLine] {
        let level = AppPreferences.shared.logLevel.uppercased()
        guard level != "ALL" else { return logLines }
        let minPriority = Self.levelPriority(level)
        return logLines.filter { line in
            guard let lineLevel = line.level else { return true }
            return Self.levelPriority(lineLevel) >= minPriority
        }
    }

    private static func levelPriority(_ level: String) -> Int {
        switch level.uppercased() {
        case "DEBUG": return 0
        case "INFO":  return 1
        case "WARN", "WARNING": return 2
        case "ERROR": return 3
        default: return 0
        }
    }

    private let appLogDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Logs/VPNFix"
    }()
    private var appLogPath: String { "\(appLogDir)/vpn-monitor.log" }
    private let helperLogPath = "/tmp/vpn-monitor.log"

    private var appFileHandle: FileHandle?
    private var helperFileHandle: FileHandle?
    private var appSource: DispatchSourceFileSystemObject?
    private var helperSource: DispatchSourceFileSystemObject?

    func startTailing() {
        ensureAppLogExists()
        loadExistingContent()
        watchForChanges()
    }

    func stopTailing() {
        appSource?.cancel()
        appSource = nil
        appFileHandle?.closeFile()
        appFileHandle = nil

        helperSource?.cancel()
        helperSource = nil
        helperFileHandle?.closeFile()
        helperFileHandle = nil
    }

    func clearLogs() {
        logLines.removeAll()
        // Truncate the app log (preserves inode, unlike atomically:true which replaces the file)
        if let handle = FileHandle(forWritingAtPath: appLogPath) {
            handle.truncateFile(atOffset: 0)
            handle.closeFile()
        }
        // Restart watchers to reset file descriptor positions
        stopTailing()
        watchForChanges()
    }

    // MARK: - Private

    private func ensureAppLogExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appLogDir) {
            try? fm.createDirectory(atPath: appLogDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: appLogPath) {
            fm.createFile(atPath: appLogPath, contents: nil)
        }
    }

    private func loadExistingContent() {
        var allLines: [LogLine] = []

        // Load app log
        if let data = FileManager.default.contents(atPath: appLogPath),
           let content = String(data: data, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { parseLine($0) }
            allLines.append(contentsOf: lines)
        }

        // Load helper log (read-only)
        if let data = FileManager.default.contents(atPath: helperLogPath),
           let content = String(data: data, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { parseLine($0) }
            allLines.append(contentsOf: lines)
        }

        // Sort by timestamp
        allLines.sort { a, b in
            guard let ta = a.timestamp, let tb = b.timestamp else {
                return a.timestamp != nil
            }
            return ta < tb
        }

        DispatchQueue.main.async {
            self.logLines = allLines
        }
    }

    private func watchForChanges() {
        watchFile(path: appLogPath, isAppLog: true)
        watchFile(path: helperLogPath, isAppLog: false)
    }

    private func watchFile(path: String, isAppLog: Bool) {
        let fd = open(path, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }

        // Seek to end to only get new content
        lseek(fd, 0, SEEK_END)

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let data = handle.availableData
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

        source.setCancelHandler {
            close(fd)
        }

        source.resume()

        if isAppLog {
            appFileHandle = handle
            appSource = source
        } else {
            helperFileHandle = handle
            helperSource = source
        }
    }

    /// Parse a log line like: "2026-03-17 10:30:45 [INFO] Some message"
    private func parseLine(_ raw: String) -> LogLine {
        let pattern = #"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+\[([^\]]+)\]\s+(.*)$"#
        let groups = raw.captureGroups(pattern: pattern)
        if groups.count >= 3 {
            return LogLine(timestamp: groups[0], level: groups[1], message: groups[2], raw: raw)
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
