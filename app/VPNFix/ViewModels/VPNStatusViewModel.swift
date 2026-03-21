import SwiftUI

/// Drives the menu bar UI state. Receives state updates from the helper via XPC.
@MainActor
final class VPNStatusViewModel: ObservableObject {
    @Published var state: VPNState = .unknown
    @Published var helperConnected: Bool = false
    @Published var lastFixMessage: String = ""
    @Published var detectedClientCount: Int = 0
    @Published var clientsWithIssues: Int = 0
    @Published var monitoringEnabled: Bool {
        didSet {
            AppPreferences.shared.monitoringEnabled = monitoringEnabled
            toggleMonitoring()
        }
    }

    private let xpcClient = XPCClient.shared
    private var pollTimer: Timer?
    private var startupTimer: Timer?
    private var startupRetryCount = 0
    private var fixTimeoutWork: DispatchWorkItem?

    init() {
        self.monitoringEnabled = AppPreferences.shared.monitoringEnabled
        AppLogger.shared.debug("VPNStatusViewModel initialized (monitoring=\(monitoringEnabled))")
        setupXPCCallbacks()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        startupTimer?.invalidate()
        AppLogger.shared.debug("VPNStatusViewModel destroyed, timers invalidated")
    }

    // MARK: - Public

    func runFix() {
        guard state != .fixing else { return }
        AppLogger.shared.info("Manual fix requested")
        state = .fixing

        // 30-second timeout in case XPC reply never arrives
        let timeout = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                guard self?.state == .fixing else { return }
                AppLogger.shared.error("Fix timed out after 30 seconds")
                self?.lastFixMessage = "Fix timed out — the helper may not be responding"
                self?.state = .unknown
                self?.refreshState()
            }
        }
        fixTimeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)

        AppLogger.shared.info("Sending fix command to helper...")

        xpcClient.runFix { [weak self] success, message in
            DispatchQueue.main.async {
                // Cancel the timeout since we got a response
                self?.fixTimeoutWork?.cancel()
                self?.fixTimeoutWork = nil

                AppLogger.shared.info("Fix result: success=\(success), message=\(message)")
                self?.lastFixMessage = message
                self?.refreshState()

                if success {
                    NotificationService.shared.postFixApplied(message: message)
                }
            }
        }
    }

    func refreshState() {
        xpcClient.getVPNState { [weak self] stateString in
            DispatchQueue.main.async {
                let newState = VPNState(rawValue: stateString) ?? .unknown
                let oldState = self?.state
                self?.state = newState

                if oldState != newState {
                    AppLogger.shared.debug("VPN state changed: \(oldState?.rawValue ?? "nil") → \(newState.rawValue)")
                    switch newState {
                    case .connected:
                        NotificationService.shared.postVPNConnected()
                    case .disconnected:
                        NotificationService.shared.postVPNDisconnected()
                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Private

    private func setupXPCCallbacks() {
        AppLogger.shared.debug("Registering XPC state change callbacks")
        xpcClient.onStateChanged = { [weak self] stateString in
            DispatchQueue.main.async {
                let newState = VPNState(rawValue: stateString) ?? .unknown
                let oldState = self?.state

                self?.state = newState
                self?.helperConnected = true

                // Post notifications based on state transitions
                if oldState != newState {
                    AppLogger.shared.debug("VPN state changed: \(oldState?.rawValue ?? "nil") → \(newState.rawValue)")
                    switch newState {
                    case .connected:
                        NotificationService.shared.postVPNConnected()
                    case .disconnected:
                        NotificationService.shared.postVPNDisconnected()
                    default:
                        break
                    }
                }
            }
        }

        xpcClient.onConnectionStateChanged = { [weak self] connected in
            AppLogger.shared.debug("Helper connection state: \(connected ? "connected" : "disconnected")")
            DispatchQueue.main.async {
                self?.helperConnected = connected
            }
        }
    }

    private func startPolling() {
        AppLogger.shared.debug("Starting local VPN detection (pre-XPC)...")
        // Immediate local detection so we have state before XPC is ready
        performLocalVPNDetection()

        // Rapid startup retries: every 1s for 5 attempts via XPC
        startupRetryCount = 0
        AppLogger.shared.debug("Starting rapid startup retries (1s interval, max 5)")
        startupTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.startupRetryCount += 1
            AppLogger.shared.debug("Startup retry \(self.startupRetryCount)/5")
            self.refreshState()
            if self.startupRetryCount >= 5 {
                AppLogger.shared.debug("Startup retries complete, switching to normal polling")
                timer.invalidate()
                self.startupTimer = nil
            }
        }

        // Normal 10-second polling as fallback to XPC push notifications
        AppLogger.shared.debug("Poll timer started (10s interval)")
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshState()
        }

        // Initial XPC fetch
        refreshState()
    }

    /// Runs `netstat -rn` directly in the app process (no root required) to detect VPN state
    /// immediately on launch, before the XPC helper is available.
    private func performLocalVPNDetection() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let connected = Self.detectVPNViaNetstat()
            DispatchQueue.main.async {
                guard let self = self, self.state == .unknown else { return }
                let detected: VPNState = connected ? .connected : .disconnected
                AppLogger.shared.debug("Local VPN detection: \(detected.rawValue)")
                self.state = detected
            }
        }
    }

    /// Checks the routing table for OpenVPN's signature routes using the shared parser.
    static func detectVPNViaNetstat() -> Bool {
        AppLogger.shared.debug("Local VPN detection: running netstat -rn...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-rn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let result = RoutingTableParser.detectVPNFromNetstat(output)
            AppLogger.shared.debug("Local VPN detection: \(result ? "connected" : "disconnected")")
            return result
        } catch {
            AppLogger.shared.error("Local VPN detection failed: \(error.localizedDescription)")
            return false
        }
    }

    private func refreshClientCounts() {
        xpcClient.detectAllVPNClients { [weak self] json in
            guard let data = json.data(using: .utf8),
                  let statuses = try? JSONDecoder().decode([VPNClientStatus].self, from: data) else { return }
            DispatchQueue.main.async {
                self?.detectedClientCount = statuses.filter { $0.connectionState == .connected }.count
                self?.clientsWithIssues = statuses.reduce(0) { $0 + $1.issueCount }
            }
        }
    }

    private func toggleMonitoring() {
        AppLogger.shared.info("Monitoring \(monitoringEnabled ? "enabled" : "disabled")")
        if monitoringEnabled {
            xpcClient.installWatcher { _, _ in }
        } else {
            xpcClient.uninstallWatcher { _, _ in }
        }
    }
}
