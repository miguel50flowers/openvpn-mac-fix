import SwiftUI

/// Drives the menu bar UI state. Receives state updates from the helper via XPC.
final class VPNStatusViewModel: ObservableObject {
    @Published var state: VPNState = .unknown
    @Published var helperConnected: Bool = false
    @Published var lastFixMessage: String = ""
    @Published var monitoringEnabled: Bool {
        didSet {
            AppPreferences.shared.monitoringEnabled = monitoringEnabled
            toggleMonitoring()
        }
    }

    private let xpcClient = XPCClient.shared
    private var pollTimer: Timer?

    init() {
        self.monitoringEnabled = AppPreferences.shared.monitoringEnabled
        setupXPCCallbacks()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Public

    func runFix() {
        guard state != .fixing else { return }
        state = .fixing

        xpcClient.runFix { [weak self] success, message in
            DispatchQueue.main.async {
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
        xpcClient.onStateChanged = { [weak self] stateString in
            DispatchQueue.main.async {
                let newState = VPNState(rawValue: stateString) ?? .unknown
                let oldState = self?.state

                self?.state = newState
                self?.helperConnected = true

                // Post notifications based on state transitions
                if oldState != newState {
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
            DispatchQueue.main.async {
                self?.helperConnected = connected
            }
        }
    }

    private func startPolling() {
        // Poll every 10 seconds as a fallback to XPC push notifications
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
        // Initial fetch
        refreshState()
    }

    private func toggleMonitoring() {
        if monitoringEnabled {
            xpcClient.installWatcher { _, _ in }
        } else {
            xpcClient.uninstallWatcher { _, _ in }
        }
    }
}
