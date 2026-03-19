import Foundation

/// Centralized logger for the helper daemon.
/// Writes to /tmp/vpn-monitor.log in a format compatible with the app's LogViewModel parser.
final class HelperLogger {
    static let shared = HelperLogger()

    private let logPath = "/tmp/vpn-monitor.log"
    private let maxFileSize: UInt64 = 1_048_576 // 1 MB
    private let queue = DispatchQueue(label: "com.vpnfix.logger")

    private init() {
        ensureLogFileExists()
    }

    // MARK: - Public API

    func debug(_ message: String) {
        write(level: "DEBUG", message: message)
    }

    func info(_ message: String) {
        write(level: "INFO", message: message)
    }

    func warn(_ message: String) {
        write(level: "WARN", message: message)
    }

    func error(_ message: String) {
        write(level: "ERROR", message: message)
    }

    // MARK: - Private

    private func write(level: String, message: String) {
        queue.async { [self] in
            let timestamp = Self.dateFormatter.string(from: Date())
            let line = "\(timestamp) [\(level)] \(message)\n"

            ensureLogFileExists()
            rotateIfNeeded()

            guard let data = line.data(using: .utf8),
                  let handle = FileHandle(forWritingAtPath: logPath) else {
                return
            }

            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }

    private func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
              let size = attrs[.size] as? UInt64,
              size > maxFileSize else {
            return
        }

        let backupPath = logPath + ".old"
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.moveItem(atPath: logPath, toPath: backupPath)
        FileManager.default.createFile(atPath: logPath, contents: nil)
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()
}
