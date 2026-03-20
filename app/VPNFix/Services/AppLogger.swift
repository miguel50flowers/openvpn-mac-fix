import Foundation

/// App-side logger that writes to the same log file as the helper daemon.
/// Enables log viewer to show app events alongside helper events.
final class AppLogger {
    static let shared = AppLogger()

    private let logPath = "/tmp/vpn-monitor.log"
    private let queue = DispatchQueue(label: "com.vpnfix.applogger")

    private init() {
        ensureLogFileWritable()
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

            ensureLogFileWritable()

            guard let data = line.data(using: .utf8) else { return }

            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                NSLog("[AppLogger] FileHandle nil, fallback: %@", line.trimmingCharacters(in: .newlines))
            }
        }
    }

    private func ensureLogFileWritable() {
        let fm = FileManager.default
        if fm.fileExists(atPath: logPath) {
            if !fm.isWritableFile(atPath: logPath) {
                // Attempt chmod 666 — works only if current user owns the file
                try? fm.setAttributes([.posixPermissions: 0o666], ofItemAtPath: logPath)
            }
        } else {
            fm.createFile(atPath: logPath, contents: nil)
            try? fm.setAttributes([.posixPermissions: 0o666], ofItemAtPath: logPath)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()
}
