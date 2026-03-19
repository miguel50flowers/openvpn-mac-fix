import Foundation

/// Manages privileged helper daemon lifecycle using NSAppleScript for admin privileges.
/// Replaces SMAppService.daemon() which requires proper Apple Developer code signing.
final class HelperInstaller {
    static let shared = HelperInstaller()

    private let helperLabel = XPCConstants.machServiceName
    private let installPath = "/Library/PrivilegedHelperTools/VPNFixHelper"
    private let resourcesPath = "/Library/PrivilegedHelperTools/VPNFixResources"
    private let plistPath = "/Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist"

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

        return Status(binaryInstalled: binaryExists, daemonLoaded: daemonLoaded)
    }

    // MARK: - Install

    func installIfNeeded() {
        let status = checkStatus()
        if status.isActive { return }
        install()
    }

    func install() {
        guard let helperSource = Bundle.main.path(forAuxiliaryExecutable: "VPNFixHelper") else {
            NSLog("[VPNFix] Helper binary not found in app bundle")
            return
        }

        guard let resourcesSource = Bundle.main.resourcePath else {
            NSLog("[VPNFix] Resources path not found in app bundle")
            return
        }

        let plistContent = generatePlist()
        let escapedPlist = plistContent.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let commands = [
            // Create directories
            "mkdir -p '\(resourcesPath)'",
            // Copy helper binary
            "cp '\(helperSource)' '\(installPath)'",
            // Copy scripts and VERSION
            "cp '\(resourcesSource)/'*.sh '\(resourcesPath)/' 2>/dev/null || true",
            "cp '\(resourcesSource)/VERSION' '\(resourcesPath)/VERSION' 2>/dev/null || true",
            // Set permissions
            "chown root:wheel '\(installPath)'",
            "chmod 755 '\(installPath)'",
            "chown -R root:wheel '\(resourcesPath)'",
            "chmod -R 755 '\(resourcesPath)'",
            // Write launchd plist
            "echo \"\(escapedPlist)\" > '\(plistPath)'",
            "chown root:wheel '\(plistPath)'",
            "chmod 644 '\(plistPath)'",
            // Load daemon
            "launchctl bootout system/\(helperLabel) 2>/dev/null || true",
            "launchctl bootstrap system '\(plistPath)'"
        ]

        let fullCommand = commands.joined(separator: " && ")
        runWithAdminPrivileges(fullCommand)
    }

    // MARK: - Uninstall

    func uninstall() {
        let commands = [
            "launchctl bootout system/\(helperLabel) 2>/dev/null || true",
            "rm -f '\(installPath)'",
            "rm -rf '\(resourcesPath)'",
            "rm -f '\(plistPath)'"
        ]

        let fullCommand = commands.joined(separator: " && ")
        runWithAdminPrivileges(fullCommand)
    }

    // MARK: - Reinstall

    func reinstall() {
        guard let helperSource = Bundle.main.path(forAuxiliaryExecutable: "VPNFixHelper") else {
            NSLog("[VPNFix] Helper binary not found in app bundle")
            return
        }

        guard let resourcesSource = Bundle.main.resourcePath else {
            NSLog("[VPNFix] Resources path not found in app bundle")
            return
        }

        let plistContent = generatePlist()
        let escapedPlist = plistContent.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let commands = [
            // Uninstall
            "launchctl bootout system/\(helperLabel) 2>/dev/null || true",
            "rm -f '\(installPath)'",
            "rm -rf '\(resourcesPath)'",
            "rm -f '\(plistPath)'",
            // Install
            "mkdir -p '\(resourcesPath)'",
            "cp '\(helperSource)' '\(installPath)'",
            "cp '\(resourcesSource)/'*.sh '\(resourcesPath)/' 2>/dev/null || true",
            "cp '\(resourcesSource)/VERSION' '\(resourcesPath)/VERSION' 2>/dev/null || true",
            "chown root:wheel '\(installPath)'",
            "chmod 755 '\(installPath)'",
            "chown -R root:wheel '\(resourcesPath)'",
            "chmod -R 755 '\(resourcesPath)'",
            "echo \"\(escapedPlist)\" > '\(plistPath)'",
            "chown root:wheel '\(plistPath)'",
            "chmod 644 '\(plistPath)'",
            "launchctl bootstrap system '\(plistPath)'"
        ]

        let fullCommand = commands.joined(separator: " && ")
        runWithAdminPrivileges(fullCommand)
    }

    // MARK: - Private

    private func generatePlist() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(helperLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(installPath)</string>
            </array>
            <key>MachServices</key>
            <dict>
                <key>\(helperLabel)</key>
                <true/>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private func runWithAdminPrivileges(_ command: String) {
        let escapedCommand = command.replacingOccurrences(of: "'", with: "'\\''")
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        guard let appleScript = NSAppleScript(source: script) else {
            NSLog("[VPNFix] Failed to create AppleScript")
            return
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error {
            NSLog("[VPNFix] Admin command failed: \(error)")
        } else {
            NSLog("[VPNFix] Helper installation completed successfully")
        }
    }
}
