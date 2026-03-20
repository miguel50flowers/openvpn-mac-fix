import Foundation

/// App-side logger that writes to the same log file as the helper daemon.
/// Enables log viewer to show app events alongside helper events.
final class AppLogger {
    static let shared = AppLogger()

    private let logPath = "/tmp/vpn-monitor.log"
    private let queue = DispatchQueue(label: "com.vpnfix.applogger")

    private init() {
        ensureLogFileExists()
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

    func debug(_ message: String) {
        write(level: "DEBUG", message: message)
    }

    private func write(level: String, message: String) {
        queue.async { [self] in
            let timestamp = Self.dateFormatter.string(from: Date())
            let line = "\(timestamp) [\(level)] [App] \(message)\n"

            ensureLogFileExists()

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
            try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: logPath)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()
}
