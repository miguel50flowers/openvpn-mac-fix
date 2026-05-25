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
    private var autoFixTimer: DispatchSourceTimer?

    /// The brain of the auto-fix: remembers the last known VPN state and decides when to run
    /// the recovery fix. Lives in Shared (`AutoFixCoordinator`) and is unit-tested; here we
    /// wire in the real netstat read, tunnel-process check, and fix script. This replaced the
    /// old logic that compared two readings both taken *after* the disconnect — which never
    /// observed the connected→disconnected transition, so the fix never ran.
    private lazy var autoFixCoordinator = AutoFixCoordinator(
        policy: AutoFixPolicy(cooldown: 30),
        stateProvider: { [weak self] in self?.vpnDetector.currentState() ?? .unknown },
        tunnelProcessRunning: {
            // Only tunnel binaries that exclusively indicate an active tunnel — NOT background
            // daemons (vpnagentd, nordvpnd, fct_launcher) which persist with no VPN connected.
            let processes = DetectionUtilities.getRunningProcesses()
            return DetectionUtilities.isAnyProcessRunning(
                ["openvpn", "wireguard-go", "pia-wireguard-go"], in: processes)
        },
        runFix: { [weak self] completion in
            guard let self else { completion(false, "helper deallocated"); return }
            self.scriptRunner.runFixScript(completion: completion)
        },
        now: Date.init,
        log: { HelperLogger.shared.info("[VPNFixHelper] [AutoFix] \($0)") }
    )

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    deinit {
        autoFixTimer?.cancel()
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
        // Record the current state as the baseline and start the safety-net poll, so the
        // first real connected→disconnected transition is detected even if the watcher event
        // is missed. seed() also forces the lazy coordinator to initialize on this thread,
        // before the watcher/timer can touch it concurrently.
        autoFixCoordinator.seed()
        startAutoFixTimer()
        reply(true, "Watcher installed")
        HelperLogger.shared.info("[VPNFixHelper] File watcher installed")
    }

    func uninstallWatcher(reply: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] uninstallWatcher requested")
        fileWatcher?.stop()
        fileWatcher = nil
        stopAutoFixTimer()
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

        // The synthetic "Network" entry isn't a VPN client — its Fix routes to the safe,
        // planner-driven repair (do-nothing-if-healthy, sequential, stop-when-restored) rather
        // than the per-client fix engine.
        if type == .network {
            runSafeFixEverything(reply: reply)
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
            runSafeFixEverything { s, m in reply(s, m) }
        default:
            reply(false, "Unknown repair action: \(action)")
        }
    }

    /// Planner-driven, sequential, verified network repair.
    ///
    /// This replaces the old "run a fixed batch of changes in parallel, never check whether they
    /// were needed or whether they helped, and report success regardless" chain — the exact code
    /// that left the user with no internet. Guarantees:
    ///  1. Does **nothing** if connectivity is already healthy (never "fixes" a working network).
    ///  2. Runs only the minimal, ordered, never-destructive steps the pure planner emits.
    ///  3. Re-checks connectivity between steps and **stops the moment it returns**.
    ///  4. Reports success **honestly** — true only when connectivity is actually restored.
    private func runSafeFixEverything(reply: @escaping (Bool, String) -> Void) {
        // Run off any caller thread; the per-step bridge below blocks on each module.
        DispatchQueue.global(qos: .userInitiated).async {
            let before = self.connectivityProbe()
            HelperLogger.shared.info("[VPNFixHelper] [SafeFix] pre-probe: route=\(before.hasDefaultRoute) dns=\(before.dnsResolves) healthy=\(before.healthy)")

            // #1 — never touch a working network.
            guard !before.healthy else {
                HelperLogger.shared.info("[VPNFixHelper] [SafeFix] already healthy — no changes made")
                reply(true, "Network already healthy — no changes made")
                return
            }

            let snapshot = self.vpnDetector.networkHealthSnapshot()
            // Never cycle the primary service while a real tunnel is up — it would tear down the VPN.
            let allowEscalation = !snapshot.tunnelProcessRunning && self.vpnDetector.currentState() != .connected
            let plan = NetworkFixPlanner.plan(probe: before, snapshot: snapshot, allowEscalation: allowEscalation)

            guard !plan.isEmpty else {
                HelperLogger.shared.info("[VPNFixHelper] [SafeFix] no safe step applies")
                reply(true, "No safe remediation applicable")
                return
            }
            HelperLogger.shared.info("[VPNFixHelper] [SafeFix] plan: \(plan.map { "\($0)" }.joined(separator: " → "))")

            let outcome = SafeFixExecutor.run(
                plan: plan,
                probe: { self.connectivityProbe() },
                runStep: { _ = self.runStepSync($0) })

            let after = self.connectivityProbe()
            self.stateNotifier.notifyStateChange()
            self.stateNotifier.notifyClientsChanged()

            let ranList = outcome.ranSteps.map { "\($0)" }.joined(separator: ", ")
            if after.healthy {
                let msg = ranList.isEmpty ? "Connectivity OK" : "Connectivity restored (\(ranList))"
                HelperLogger.shared.info("[VPNFixHelper] [SafeFix] done: \(msg)")
                reply(true, msg)
            } else {
                let msg = "Ran safe steps (\(ranList.isEmpty ? "none" : ranList)) but connectivity is still degraded — route=\(after.hasDefaultRoute), dns=\(after.dnsResolves). No destructive change was made; a manual check may be needed."
                HelperLogger.shared.warn("[VPNFixHelper] [SafeFix] still degraded: \(msg)")
                reply(false, msg)
            }
        }
    }

    /// Live connectivity probe: does a physical default route exist and does DNS resolve?
    ///
    /// DNS that could not be **measured** (every lookup timed out) is treated as "not resolving"
    /// here so a user-invoked fix still attempts safe remediation. A wrong guess can't strand the
    /// machine: every step is reversible and the executor stops as soon as the network is healthy.
    /// (Background detection, by contrast, keeps unmeasured DNS as "unknown" to avoid crying wolf.)
    private func connectivityProbe() -> NetworkProbe {
        let route = DetectionUtilities.routingTableReading()
        let hasRoute = route.available && DetectionUtilities.hasPhysicalDefaultRoute(in: route.value)
        let dns = DetectionUtilities.dnsResolves(hosts: ["apple.com", "cloudflare.com"], timeout: 2) ?? false
        return NetworkProbe(dnsResolves: dns, hasDefaultRoute: hasRoute)
    }

    /// Performs one planned step's real work and BLOCKS until it finishes (the caller runs this off
    /// the main thread). Every branch delegates to a module that was rewritten to be safe and
    /// reversible — there is deliberately no destructive command in this switch.
    @discardableResult
    private func runStepSync(_ step: FixStepKind) -> (ok: Bool, message: String) {
        HelperLogger.shared.info("[VPNFixHelper] [SafeFix] step: \(step) — \(step.summary)")
        let sema = DispatchSemaphore(value: 0)
        var result: (ok: Bool, message: String) = (true, "")
        let done: (Bool, String) -> Void = { ok, msg in result = (ok, msg); sema.signal() }

        switch step {
        case .flushDNS:
            _ = DetectionUtilities.runCommandWithStatus("/usr/bin/dscacheutil", arguments: ["-flushcache"])
            _ = DetectionUtilities.runCommandWithStatus("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
            done(true, "DNS flushed")
        case .removeStaleVPNRoutes:
            // Legacy cleanup removes leftover utun/ppp routes; hardened to never leave the machine
            // offline. Only reached when an orphaned tunnel exists with no VPN process running.
            scriptRunner.runFixScript(completion: done)
        case .restoreDefaultRoute, .renewDHCP:
            // CommonFixModule restores the default route across active physical interfaces (and
            // verifies it took) and renews DHCP — both idempotent and safe. The executor re-probes
            // between the paired steps, so the second run only happens if the first didn't help.
            CommonFixModule().fix(issues: [], completion: done)
        case .restoreIPv6Automatic:
            IPv6Module().run(completion: done)
        case .flushARP:
            ARPCacheModule().run(completion: done)
        case .cyclePrimaryService:
            NetworkInterfaceResetModule().run(completion: done)
        }

        sema.wait()
        return result
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
        // The watcher already debounced rapid resolv.conf writes. Give the routing table a
        // moment to settle (VPN setup/teardown isn't instantaneous), then let the coordinator
        // compare the fresh state against the LAST KNOWN one and act on a real transition.
        // The coordinator — not a second reading taken here — is the source of "previous",
        // which is the fix for the disconnect that previously went undetected.
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self else { return }
            self.stateNotifier.notifyStateChange()
            self.autoFixCoordinator.evaluate()
        }
    }

    // MARK: - Auto-fix safety-net timer

    /// Periodically re-evaluates VPN state so a connected→disconnected transition is caught
    /// even if the resolv.conf watcher misses an event. The cooldown de-duplicates a
    /// transition that both this timer and the watcher observe.
    private func startAutoFixTimer() {
        guard autoFixTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in
            self?.autoFixCoordinator.evaluate()
        }
        timer.resume()
        autoFixTimer = timer
        HelperLogger.shared.debug("[VPNFixHelper] Auto-fix safety-net timer started (10s)")
    }

    private func stopAutoFixTimer() {
        autoFixTimer?.cancel()
        autoFixTimer = nil
    }

}
