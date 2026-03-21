import Foundation

/// Centralized logger for the helper daemon.
/// Writes to /var/log/VPNFix/vpn-monitor.log with root-write, world-read permissions.
final class HelperLogger {
    static let shared = HelperLogger()

    private let logDir = "/var/log/VPNFix"
    private let logPath = "/var/log/VPNFix/vpn-monitor.log"
    private let maxFileSize: UInt64 = 1_048_576 // 1 MB
    private let queue = DispatchQueue(label: "com.vpnfix.logger")

    private init() {
        ensureLogDirectoryExists()
        ensureLogFileExists()
    }

    /// Minimum log level to write. Set via VPN_MONITOR_LOG_LEVEL environment variable.
    private let minLevel: Int = {
        let env = ProcessInfo.processInfo.environment["VPN_MONITOR_LOG_LEVEL"]?.uppercased() ?? "DEBUG"
        return levelPriority(env)
    }()

    private static func levelPriority(_ level: String) -> Int {
        switch level {
        case "DEBUG": return 0
        case "INFO":  return 1
        case "WARN":  return 2
        case "ERROR": return 3
        default: return 0
        }
    }

    // MARK: - Public API

    func debug(_ message: String) {
        guard minLevel <= 0 else { return }
        write(level: "DEBUG", message: message)
    }

    func info(_ message: String) {
        guard minLevel <= 1 else { return }
        write(level: "INFO", message: message)
    }

    func warn(_ message: String) {
        guard minLevel <= 2 else { return }
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

            guard let data = line.data(using: .utf8) else { return }

            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                NSLog("[HelperLogger] FileHandle nil, fallback: %@", line.trimmingCharacters(in: .newlines))
            }
        }
    }

    private func ensureLogDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        }
        // root:wheel owned, world-readable directory
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: logDir)
    }

    private func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        // root-write, world-read (no world-write to prevent log injection)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: logPath)
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
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: backupPath)
        FileManager.default.createFile(atPath: logPath, contents: nil)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: logPath)
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()
}
