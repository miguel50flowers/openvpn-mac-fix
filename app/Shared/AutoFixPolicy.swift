import Foundation

/// Why an auto-fix was not run. Surfaced for logging and asserted in tests.
enum AutoFixSkipReason: Equatable, CustomStringConvertible {
    case noDisconnectTransition
    case cooldownActive
    case tunnelProcessRunning

    var description: String {
        switch self {
        case .noDisconnectTransition: return "no connected→disconnected transition"
        case .cooldownActive: return "cooldown active"
        case .tunnelProcessRunning: return "VPN tunnel process still running"
        }
    }
}

/// The outcome of evaluating whether to run the network-recovery fix.
enum AutoFixDecision: Equatable {
    case runFix
    case skip(AutoFixSkipReason)
}

/// Pure decision logic for auto-fixing the network after a VPN disconnect.
///
/// The fix runs only on a genuine `connected → disconnected` transition, outside the
/// cooldown window, and only when no VPN tunnel process is still running (a running
/// tunnel binary means the VPN is connecting/reconnecting, not truly down).
///
/// This is intentionally free of I/O and time/process dependencies so the behavior that
/// regressed — never firing on a real disconnect — is locked down by fast unit tests.
struct AutoFixPolicy {
    let cooldown: TimeInterval

    init(cooldown: TimeInterval = 30) {
        self.cooldown = cooldown
    }

    func decide(previous: VPNState,
                current: VPNState,
                lastFix: Date,
                now: Date,
                tunnelProcessRunning: Bool) -> AutoFixDecision {
        guard previous == .connected, current == .disconnected else {
            return .skip(.noDisconnectTransition)
        }
        if now.timeIntervalSince(lastFix) < cooldown {
            return .skip(.cooldownActive)
        }
        if tunnelProcessRunning {
            return .skip(.tunnelProcessRunning)
        }
        return .runFix
    }
}
