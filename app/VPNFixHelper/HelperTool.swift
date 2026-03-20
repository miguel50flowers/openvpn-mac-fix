import Foundation

// MARK: - XPC Listener Delegate

final class HelperToolDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        #if !DEBUG
        // Verify the calling app's code signature
        guard verifyCallerSignature(connection: newConnection) else {
            HelperLogger.shared.info("[VPNFixHelper] Rejected connection: invalid code signature")
            return false
        }
        #endif

        newConnection.exportedInterface = NSXPCInterface(with: VPNHelperProtocol.self)
        newConnection.exportedObject = HelperTool(connection: newConnection)

        // Set up reverse channel so we can push state changes to the app
        newConnection.remoteObjectInterface = NSXPCInterface(with: VPNAppProtocol.self)

        newConnection.invalidationHandler = {
            HelperLogger.shared.info("[VPNFixHelper] Connection invalidated")
        }

        newConnection.resume()
        HelperLogger.shared.info("[VPNFixHelper] Accepted new connection")
        return true
    }

    private func verifyCallerSignature(connection: NSXPCConnection) -> Bool {
        // Verify the connecting process has the expected code signature
        let pid = connection.processIdentifier
        var code: SecCode?

        let attributes = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let secCode = code else {
            return false
        }

        // Require the app's bundle identifier (ad-hoc signing compatible)
        let requirement = "identifier \"\(XPCConstants.appBundleID)\""
        var secRequirement: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &secRequirement) == errSecSuccess,
              let req = secRequirement else {
            return false
        }

        return SecCodeCheckValidity(secCode, [], req) == errSecSuccess
    }
}

// MARK: - Helper Tool Implementation

final class HelperTool: NSObject, VPNHelperProtocol {
    private let connection: NSXPCConnection
    private let vpnDetector = VPNDetector()
    private let scriptRunner = ScriptRunner()
    private var fileWatcher: FileWatcher?

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    func getVPNState(reply: @escaping (String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] getVPNState requested")
        let state = vpnDetector.currentState()
        HelperLogger.shared.debug("[VPNFixHelper] getVPNState result: \(state.rawValue)")
        reply(state.rawValue)
    }

    func runFix(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] Running VPN fix...")
        scriptRunner.runFixScript { success, output in
            HelperLogger.shared.info("[VPNFixHelper] Fix completed: success=\(success)")
            // Notify the app of the new state
            self.notifyAppOfStateChange()
            reply(success, output)
        }
    }

    func installWatcher(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] installWatcher requested")
        if fileWatcher != nil {
            HelperLogger.shared.debug("[VPNFixHelper] Watcher already active, skipping")
            reply(true, "Watcher already active")
            return
        }

        fileWatcher = FileWatcher { [weak self] in
            self?.handleResolvConfChange()
        }
        fileWatcher?.start()
        reply(true, "Watcher installed")
        HelperLogger.shared.info("[VPNFixHelper] File watcher installed")
    }

    func uninstallWatcher(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] uninstallWatcher requested")
        fileWatcher?.stop()
        fileWatcher = nil
        reply(true, "Watcher removed")
        HelperLogger.shared.info("[VPNFixHelper] File watcher removed")
    }

    func getVersion(reply: @escaping (String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] getVersion requested")
        // Try installed resources path first, then bundle-relative
        let installedVersionPath = "/Library/PrivilegedHelperTools/VPNFixResources/VERSION"

        if let version = try? String(contentsOfFile: installedVersionPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            HelperLogger.shared.debug("[VPNFixHelper] Version from installed path: \(version)")
            reply(version)
            return
        }

        // Fallback: bundle-relative path
        let helperPath = ProcessInfo.processInfo.arguments[0]
        let contentsURL = URL(fileURLWithPath: helperPath)
            .deletingLastPathComponent() // MacOS/
            .deletingLastPathComponent() // Contents/
        let versionURL = contentsURL.appendingPathComponent("Resources/VERSION")

        if let version = try? String(contentsOf: versionURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            HelperLogger.shared.debug("[VPNFixHelper] Version from bundle path: \(version)")
            reply(version)
        } else {
            HelperLogger.shared.warn("[VPNFixHelper] VERSION file not found at installed or bundle path")
            reply("Unknown")
        }
    }

    func removePhase1Artifacts(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] removePhase1Artifacts requested")
        var removed: [String] = []
        var errors: [String] = []

        let fm = FileManager.default

        // Unload and remove old LaunchDaemon
        let plistPath = "/Library/LaunchDaemons/com.vpnmonitor.plist"
        if fm.fileExists(atPath: plistPath) {
            HelperLogger.shared.debug("[VPNFixHelper] Found Phase 1 plist: \(plistPath)")
            let unload = Process()
            unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unload.arguments = ["unload", plistPath]
            try? unload.run()
            unload.waitUntilExit()

            do {
                try fm.removeItem(atPath: plistPath)
                removed.append(plistPath)
                HelperLogger.shared.debug("[VPNFixHelper] Removed: \(plistPath)")
            } catch {
                HelperLogger.shared.error("[VPNFixHelper] Failed to remove \(plistPath): \(error.localizedDescription)")
                errors.append("Failed to remove \(plistPath): \(error.localizedDescription)")
            }
        }

        // Remove old scripts from all user home directories
        let userDirs = (try? fm.contentsOfDirectory(atPath: "/Users")) ?? []
        for user in userDirs where !user.hasPrefix(".") {
            let homePath = "/Users/\(user)"
            for script in ["vpn-monitor.sh", "fix-vpn-disconnect.sh"] {
                let scriptPath = "\(homePath)/\(script)"
                if fm.fileExists(atPath: scriptPath) {
                    HelperLogger.shared.debug("[VPNFixHelper] Found Phase 1 script: \(scriptPath)")
                    do {
                        try fm.removeItem(atPath: scriptPath)
                        removed.append(scriptPath)
                        HelperLogger.shared.debug("[VPNFixHelper] Removed: \(scriptPath)")
                    } catch {
                        HelperLogger.shared.error("[VPNFixHelper] Failed to remove \(scriptPath): \(error.localizedDescription)")
                        errors.append("Failed to remove \(scriptPath): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Clean up temp files (keep vpn-monitor.log — it's an active Phase 2 file)
        for tmp in ["/tmp/vpn-was-connected"] {
            if fm.fileExists(atPath: tmp) {
                HelperLogger.shared.debug("[VPNFixHelper] Cleaning temp file: \(tmp)")
                try? fm.removeItem(atPath: tmp)
                removed.append(tmp)
            }
        }

        if errors.isEmpty {
            HelperLogger.shared.info("[VPNFixHelper] Phase 1 removal complete: \(removed.count) files removed")
            reply(true, "Removed: \(removed.joined(separator: ", "))")
        } else {
            HelperLogger.shared.error("[VPNFixHelper] Phase 1 removal had errors: \(errors.joined(separator: "; "))")
            reply(false, "Errors: \(errors.joined(separator: "; "))")
        }
    }

    func ensureLogFilePermissions(reply: @escaping (Bool) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] ensureLogFilePermissions requested")
        let logPath = "/tmp/vpn-monitor.log"
        let fm = FileManager.default

        if !fm.fileExists(atPath: logPath) {
            fm.createFile(atPath: logPath, contents: nil)
        }

        do {
            try fm.setAttributes([.posixPermissions: 0o666], ofItemAtPath: logPath)
            HelperLogger.shared.info("[VPNFixHelper] Log file permissions set to 666")
            reply(true)
        } catch {
            HelperLogger.shared.error("[VPNFixHelper] Failed to set log file permissions: \(error.localizedDescription)")
            reply(false)
        }
    }

    // MARK: - Private

    private func handleResolvConfChange() {
        let previousState = vpnDetector.currentState()

        // Small delay to let the system settle
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            let newState = self.vpnDetector.currentState()

            HelperLogger.shared.info("[VPNFixHelper] resolv.conf changed: \(previousState.rawValue) -> \(newState.rawValue)")
            self.notifyAppOfStateChange()

            // If VPN just disconnected, run the fix
            if previousState == .connected && newState == .disconnected {
                HelperLogger.shared.info("[VPNFixHelper] VPN disconnection detected, running fix...")
                self.scriptRunner.runFixScript { success, output in
                    HelperLogger.shared.info("[VPNFixHelper] Auto-fix result: success=\(success), output=\(output)")
                    self.notifyAppOfStateChange()
                }
            } else {
                HelperLogger.shared.debug("[VPNFixHelper] State transition \(previousState.rawValue) → \(newState.rawValue), no fix needed")
            }
        }
    }

    private func notifyAppOfStateChange() {
        let state = vpnDetector.currentState()
        HelperLogger.shared.debug("[VPNFixHelper] Pushing state to app: \(state.rawValue)")
        let proxy = connection.remoteObjectProxy as? VPNAppProtocol
        proxy?.stateChanged(state.rawValue)
    }
}
