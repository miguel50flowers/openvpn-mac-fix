import Foundation

/// Manages privileged helper daemon lifecycle using NSAppleScript for admin privileges.
/// Replaces SMAppService.daemon() which requires proper Apple Developer code signing.
final class HelperInstaller {
    static let shared = HelperInstaller()

    private let helperLabel = XPCConstants.machServiceName
    private let installPath = "/Library/PrivilegedHelperTools/VPNFixHelper"
    private let resourcesPath = "/Library/PrivilegedHelperTools/VPNFixResources"
    private let plistPath = "/Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist"
    private let tmpPlistPath = "/tmp/com.miguel50flowers.VPNFix.helper.plist"

    private init() {}

    // MARK: - Status

    struct Status {
        let binaryInstalled: Bool
        let daemonLoaded: Bool

        var isActive: Bool { binaryInstalled && daemonLoaded }
        var label: String {
            if isActive { return "Active" }
            if binaryInstalled { return "Installed (not running)" }
            return "Not Installed"
        }
    }

    func checkStatus() -> Status {
        let binaryExists = FileManager.default.fileExists(atPath: installPath)
        AppLogger.shared.debug("Helper binary at \(installPath): \(binaryExists ? "exists" : "missing")")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "system/\(helperLabel)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        var daemonLoaded = false
        do {
            try process.run()
            process.waitUntilExit()
            daemonLoaded = process.terminationStatus == 0
        } catch {
            daemonLoaded = false
        }

        AppLogger.shared.debug("Helper daemon \(helperLabel): \(daemonLoaded ? "loaded" : "not loaded")")
        return Status(binaryInstalled: binaryExists, daemonLoaded: daemonLoaded)
    }

    // MARK: - Install

    func installIfNeeded() {
        let status = checkStatus()
        if status.isActive {
            AppLogger.shared.debug("Helper already active, skipping install")
            return
        }
        AppLogger.shared.info("Helper not active, installing...")
        install()
    }

    func install() {
        guard let helperSource = Bundle.main.path(forAuxiliaryExecutable: "VPNFixHelper") else {
            AppLogger.shared.error("Helper binary not found in app bundle")
            return
        }

        guard let resourcesSource = Bundle.main.resourcePath else {
            AppLogger.shared.error("Resources path not found in app bundle")
            return
        }

        // Write plist to temp file (no admin privileges needed for /tmp)
        AppLogger.shared.debug("Generating LaunchDaemon plist...")
        let plistContent = generatePlist()
        do {
            try plistContent.write(toFile: tmpPlistPath, atomically: true, encoding: .utf8)
            AppLogger.shared.debug("Temp plist written to \(tmpPlistPath)")
        } catch {
            AppLogger.shared.error("Failed to write temp plist: \(error)")
            return
        }

        AppLogger.shared.debug("Preparing admin install command...")
        let commands = [
            "mkdir -p \"\(resourcesPath)\"",
            "cp \"\(helperSource)\" \"\(installPath)\"",
            "cp \"\(resourcesSource)/\"*.sh \"\(resourcesPath)/\" 2>/dev/null || true",
            "cp \"\(resourcesSource)/VERSION\" \"\(resourcesPath)/VERSION\" 2>/dev/null || true",
            "chown root:wheel \"\(installPath)\"",
            "chmod 755 \"\(installPath)\"",
            "chown -R root:wheel \"\(resourcesPath)\"",
            "chmod -R 755 \"\(resourcesPath)\"",
            "touch /tmp/vpn-monitor.log && chmod 666 /tmp/vpn-monitor.log",
            "cp \"\(tmpPlistPath)\" \"\(plistPath)\"",
            "chown root:wheel \"\(plistPath)\"",
            "chmod 644 \"\(plistPath)\"",
            "launchctl bootout system/\(helperLabel) 2>/dev/null || true",
            "launchctl bootstrap system \"\(plistPath)\""
        ]

        let fullCommand = commands.joined(separator: " && ")
        runWithAdminPrivileges(fullCommand)
    }

    // MARK: - Uninstall

    func uninstall() {
        AppLogger.shared.info("Uninstalling helper...")
        let commands = [
            "launchctl bootout system/\(helperLabel) 2>/dev/null || true",
            "rm -f \"\(installPath)\"",
            "rm -rf \"\(resourcesPath)\"",
            "rm -f \"\(plistPath)\""
        ]

        AppLogger.shared.debug("Uninstall: removing binary, resources, and plist")
        let fullCommand = commands.joined(separator: " && ")
        runWithAdminPrivileges(fullCommand)
    }

    // MARK: - Reinstall

    func reinstall() {
        AppLogger.shared.info("Reinstalling helper...")
        guard let helperSource = Bundle.main.path(forAuxiliaryExecutable: "VPNFixHelper") else {
            AppLogger.shared.error("Helper binary not found in app bundle")
            return
        }

        guard let resourcesSource = Bundle.main.resourcePath else {
            AppLogger.shared.error("Resources path not found in app bundle")
            return
        }

        // Write plist to temp file (no admin privileges needed for /tmp)
        AppLogger.shared.debug("Generating LaunchDaemon plist for reinstall...")
        let plistContent = generatePlist()
        do {
            try plistContent.write(toFile: tmpPlistPath, atomically: true, encoding: .utf8)
            AppLogger.shared.debug("Temp plist written to \(tmpPlistPath)")
        } catch {
            AppLogger.shared.error("Failed to write temp plist: \(error)")
            return
        }

        AppLogger.shared.debug("Preparing admin reinstall command...")
        let commands = [
            "launchctl bootout system/\(helperLabel) 2>/dev/null || true",
            "rm -f \"\(installPath)\"",
            "rm -rf \"\(resourcesPath)\"",
            "rm -f \"\(plistPath)\"",
            "mkdir -p \"\(resourcesPath)\"",
            "cp \"\(helperSource)\" \"\(installPath)\"",
            "cp \"\(resourcesSource)/\"*.sh \"\(resourcesPath)/\" 2>/dev/null || true",
            "cp \"\(resourcesSource)/VERSION\" \"\(resourcesPath)/VERSION\" 2>/dev/null || true",
            "chown root:wheel \"\(installPath)\"",
            "chmod 755 \"\(installPath)\"",
            "chown -R root:wheel \"\(resourcesPath)\"",
            "chmod -R 755 \"\(resourcesPath)\"",
            "touch /tmp/vpn-monitor.log && chmod 666 /tmp/vpn-monitor.log",
            "cp \"\(tmpPlistPath)\" \"\(plistPath)\"",
            "chown root:wheel \"\(plistPath)\"",
            "chmod 644 \"\(plistPath)\"",
            "launchctl bootstrap system \"\(plistPath)\""
        ]

        let fullCommand = commands.joined(separator: " && ")
        runWithAdminPrivileges(fullCommand)
    }

    // MARK: - Private

    private func generatePlist() -> String {
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
            "<plist version=\"1.0\">",
            "<dict>",
            "    <key>Label</key>",
            "    <string>\(helperLabel)</string>",
            "    <key>ProgramArguments</key>",
            "    <array>",
            "        <string>\(installPath)</string>",
            "    </array>",
            "    <key>MachServices</key>",
            "    <dict>",
            "        <key>\(helperLabel)</key>",
            "        <true/>",
            "    </dict>",
            "    <key>RunAtLoad</key>",
            "    <true/>",
            "    <key>KeepAlive</key>",
            "    <true/>",
            "</dict>",
            "</plist>"
        ].joined(separator: "\n")
    }

    private func runWithAdminPrivileges(_ command: String) {
        AppLogger.shared.debug("Executing admin command: \(command.prefix(120))...")
        // Escape for AppleScript double-quoted string: \ → \\ then " → \"
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        guard let appleScript = NSAppleScript(source: script) else {
            AppLogger.shared.error("Failed to create AppleScript")
            return
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error {
            AppLogger.shared.error("Admin command failed: \(error)")
        } else {
            AppLogger.shared.info("Helper installation completed successfully")
        }
    }
}
