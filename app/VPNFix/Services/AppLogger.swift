import Foundation

/// App-side logger that writes to ~/Library/Logs/VPNFix/vpn-monitor.log.
/// Uses a user-writable path to avoid /tmp permission issues with root-owned files.
final class AppLogger {
    static let shared = AppLogger()

    private let logDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Logs/VPNFix"
    }()
    private var logPath: String { "\(logDir)/vpn-monitor.log" }
    private let queue = DispatchQueue(label: "com.vpnfix.applogger")

    private init() {
        ensureLogDirectory()
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

            guard let data = line.data(using: .utf8) else { return }

            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else if FileManager.default.createFile(atPath: logPath, contents: data) {
                // File was just created with the log line
            } else {
                NSLog("[AppLogger] FileHandle nil, fallback: %@", line.trimmingCharacters(in: .newlines))
            }
        }
    }

    private func ensureLogDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: logPath) {
            fm.createFile(atPath: logPath, contents: nil)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()
}
