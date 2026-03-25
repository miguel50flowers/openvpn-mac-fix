import Foundation

// MARK: - XPC Listener Delegate

final class HelperToolDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Always verify the calling app's code signature, even in debug builds.
        // A compromised or absent verification allows any process to control the root helper.
        guard verifyCallerSignature(connection: newConnection) else {
            HelperLogger.shared.info("[VPNFixHelper] Rejected connection: invalid code signature")
            return false
        }

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
    private let fixEngine = FixEngine()
    private let phase1Migrator = Phase1Migrator()
    private lazy var stateNotifier = StateNotifier(connection: connection, vpnDetector: vpnDetector)
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
            self.stateNotifier.notifyStateChange()
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
        phase1Migrator.removeArtifacts(reply: reply)
    }

    // MARK: - Phase 3: Multi-VPN Support

    func detectAllVPNClients(reply: @escaping (String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] detectAllVPNClients requested")
        let statuses = vpnDetector.detectAll()
        do {
            let data = try JSONEncoder().encode(statuses)
            guard let json = String(data: data, encoding: .utf8) else {
                HelperLogger.shared.error("[VPNFixHelper] Failed to encode VPN statuses as UTF-8")
                reply("{\"error\":\"UTF-8 encoding failed\"}")
                return
            }
            HelperLogger.shared.debug("[VPNFixHelper] Detected \(statuses.count) VPN clients")
            reply(json)
        } catch {
            HelperLogger.shared.error("[VPNFixHelper] Failed to encode VPN statuses: \(error.localizedDescription)")
            reply("{\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    func runFixForClient(_ clientType: String, reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] runFixForClient requested for: \(clientType)")
        guard let type = VPNClientType(rawValue: clientType) else {
            reply(false, "Unknown client type: \(clientType)")
            return
        }

        // Detect current issues for this client
        let statuses = vpnDetector.detectAll()
        guard let status = statuses.first(where: { $0.clientType == type }) else {
            reply(false, "Client \(type.displayName) not detected")
            return
        }

        fixEngine.fixClient(type, issues: status.detectedIssues) { success, message in
            HelperLogger.shared.info("[VPNFixHelper] Fix for \(type.displayName): success=\(success), \(message)")
            self.stateNotifier.notifyStateChange()
            reply(success, message)
        }
    }

    func runFixAll(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] runFixAll requested")
        let statuses = vpnDetector.detectAll()

        fixEngine.fixAll(statuses: statuses) { success, message in
            HelperLogger.shared.info("[VPNFixHelper] Fix all: success=\(success), \(message)")
            // Also run the legacy script for comprehensive cleanup
            self.scriptRunner.runFixScript { scriptSuccess, scriptOutput in
                HelperLogger.shared.info("[VPNFixHelper] Legacy fix script: success=\(scriptSuccess)")
                self.stateNotifier.notifyStateChange()
                self.stateNotifier.notifyClientsChanged()
                reply(success && scriptSuccess, message)
            }
        }
    }

    func getNetworkDiagnostics(reply: @escaping (String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] getNetworkDiagnostics requested")
        let diagnostics = vpnDetector.getNetworkDiagnostics()
        do {
            let data = try JSONEncoder().encode(diagnostics)
            guard let json = String(data: data, encoding: .utf8) else {
                HelperLogger.shared.error("[VPNFixHelper] Failed to encode diagnostics as UTF-8")
                reply("{\"error\":\"UTF-8 encoding failed\"}")
                return
            }
            reply(json)
        } catch {
            HelperLogger.shared.error("[VPNFixHelper] Failed to encode diagnostics: \(error.localizedDescription)")
            reply("{\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    func runNetworkRepair(_ action: String, reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] runNetworkRepair requested: \(action)")
        switch action {
        case "flushDNS":
            _ = DetectionUtilities.runCommandWithStatus("/usr/bin/dscacheutil", arguments: ["-flushcache"])
            _ = DetectionUtilities.runCommandWithStatus("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
            reply(true, "DNS cache flushed")
        case "renewDHCP":
            CommonFixModule().fix(issues: []) { s, m in reply(s, m) }
        case "resetWiFi":
            WiFiModule().run { s, m in reply(s, m) }
        case "resetInterface":
            NetworkInterfaceResetModule().run { s, m in reply(s, m) }
        case "flushARP":
            ARPCacheModule().run { s, m in reply(s, m) }
        case "toggleIPv6":
            IPv6Module().run { s, m in reply(s, m) }
        case "fixMTU":
            MTUFixModule().run { s, m in reply(s, m) }
        case "restartMDNS":
            MDNSResponderModule().run { s, m in reply(s, m) }
        case "speedTest":
            SpeedTestModule().run { s, m in reply(s, m) }
        case "resetLocation":
            NetworkLocationResetModule().run { s, m in reply(s, m) }
        case "resetNetworkPrefs":
            SystemConfigResetModule().run { s, m in reply(s, m) }
        case "fixEverything":
            runFixEverything { s, m in reply(s, m) }
        default:
            reply(false, "Unknown repair action: \(action)")
        }
    }

    private func runFixEverything(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[VPNFixHelper] Running full network repair chain")
        var results: [String] = []

        // Chain all repairs sequentially
        let modules: [(String, ((@escaping (Bool, String) -> Void) -> Void))] = [
            ("DNS", { cb in _ = DetectionUtilities.runCommandWithStatus("/usr/bin/dscacheutil", arguments: ["-flushcache"]); _ = DetectionUtilities.runCommandWithStatus("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"]); cb(true, "flushed") }),
            ("DHCP", { CommonFixModule().fix(issues: [], completion: $0) }),
            ("MTU", { MTUFixModule().run(completion: $0) }),
            ("ARP", { ARPCacheModule().run(completion: $0) }),
            ("IPv6", { IPv6Module().run(completion: $0) }),
            ("Interface", { NetworkInterfaceResetModule().run(completion: $0) }),
        ]

        let group = DispatchGroup()
        for (name, action) in modules {
            group.enter()
            action { success, message in
                results.append("\(name): \(success ? "OK" : "FAIL")")
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            let msg = results.joined(separator: ", ")
            HelperLogger.shared.info("[VPNFixHelper] Fix everything done: \(msg)")
            reply(true, msg)
        }
    }

    func setCustomVPNEntries(_ json: String, reply: @escaping (Bool) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] setCustomVPNEntries requested")
        let path = "/Library/PrivilegedHelperTools/VPNFixResources/custom-vpns.json"
        do {
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            HelperLogger.shared.info("[VPNFixHelper] Custom VPN entries saved to \(path)")
            reply(true)
        } catch {
            HelperLogger.shared.error("[VPNFixHelper] Failed to save custom VPN entries: \(error)")
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
            self.stateNotifier.notifyStateChange()

            // If VPN just disconnected, run the fix
            if previousState == .connected && newState == .disconnected {
                HelperLogger.shared.info("[VPNFixHelper] VPN disconnection detected, running fix...")
                self.scriptRunner.runFixScript { success, output in
                    HelperLogger.shared.info("[VPNFixHelper] Auto-fix result: success=\(success), output=\(output)")
                    self.stateNotifier.notifyStateChange()
                }
            } else {
                HelperLogger.shared.debug("[VPNFixHelper] State transition \(previousState.rawValue) → \(newState.rawValue), no fix needed")
            }
        }
    }

}
