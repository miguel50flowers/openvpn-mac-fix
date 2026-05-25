import Foundation

/// Tracks the last known VPN state and drives the auto-fix decision when the state changes.
///
/// This is the fix for the core bug. The previous implementation inferred the "previous"
/// state from a second live reading taken *after* the resolv.conf watcher's 3s debounce —
/// by which point the VPN was already gone from the routing table — so the
/// `connected → disconnected` transition was never observed and the fix never ran on a
/// real disconnect.
///
/// Here `lastKnownState` is carried across observations, so the transition is detected by
/// comparing the remembered previous state against a fresh reading. All side-effecting
/// dependencies are injected, so the coordinator is pure and fully testable without
/// netstat, sudo, or a real VPN. It is safe to call `evaluate()` from multiple sources
/// (the file watcher's fast path and a periodic safety-net timer): the state update is
/// serialized and the cooldown de-duplicates a transition seen by more than one driver.
final class AutoFixCoordinator {
    private let policy: AutoFixPolicy
    private let stateProvider: () -> VPNState
    private let tunnelProcessRunning: () -> Bool
    private let runFix: (@escaping (Bool, String) -> Void) -> Void
    private let now: () -> Date
    private let log: (String) -> Void

    private let lock = NSLock()
    private var lastKnownState: VPNState
    private var lastFixTime: Date

    init(policy: AutoFixPolicy,
         stateProvider: @escaping () -> VPNState,
         tunnelProcessRunning: @escaping () -> Bool,
         runFix: @escaping (@escaping (Bool, String) -> Void) -> Void,
         now: @escaping () -> Date = Date.init,
         log: @escaping (String) -> Void = { _ in },
         initialState: VPNState = .unknown,
         initialLastFix: Date = .distantPast) {
        self.policy = policy
        self.stateProvider = stateProvider
        self.tunnelProcessRunning = tunnelProcessRunning
        self.runFix = runFix
        self.now = now
        self.log = log
        self.lastKnownState = initialState
        self.lastFixTime = initialLastFix
    }

    /// Records the current state as the baseline without taking any action.
    /// Call once when monitoring starts so the first real transition is detected.
    func seed() {
        let current = stateProvider()
        lock.lock()
        lastKnownState = current
        lock.unlock()
        log("AutoFix baseline state: \(current.rawValue)")
    }

    /// Re-evaluates the VPN state. On a `connected → disconnected` transition that passes
    /// the cooldown and tunnel-process guards, runs the fix. Returns the decision taken.
    @discardableResult
    func evaluate() -> AutoFixDecision {
        let current = stateProvider()
        let timestamp = now()

        lock.lock()
        let previous = lastKnownState
        lastKnownState = current
        // The process check can do I/O; only consult it on a genuine disconnect transition.
        let isDisconnectTransition = (previous == .connected && current == .disconnected)
        let runningTunnel = isDisconnectTransition ? tunnelProcessRunning() : false
        let decision = policy.decide(previous: previous,
                                     current: current,
                                     lastFix: lastFixTime,
                                     now: timestamp,
                                     tunnelProcessRunning: runningTunnel)
        if case .runFix = decision {
            lastFixTime = timestamp
        }
        lock.unlock()

        switch decision {
        case .runFix:
            log("VPN disconnection confirmed (no VPN tunnel process running), running fix...")
            runFix { [log] success, output in
                log("Auto-fix result: success=\(success), output=\(output)")
            }
        case .skip(let reason):
            log("State \(previous.rawValue)→\(current.rawValue): no fix (\(reason))")
        }
        return decision
    }
}
