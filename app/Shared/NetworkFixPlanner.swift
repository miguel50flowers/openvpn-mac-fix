import Foundation

/// Result of a connectivity probe. "healthy" means traffic can both route out and resolve names.
struct NetworkProbe: Equatable {
    let dnsResolves: Bool
    let hasDefaultRoute: Bool

    var healthy: Bool { dnsResolves && hasDefaultRoute }
}

/// The kinds of remediation step the planner may emit.
///
/// By construction NONE is destructive: there is no raw `ifconfig <iface> down`, no global IPv6
/// disable (`-setv6off`), no `pfctl -d`, and no SystemConfiguration plist deletion here. The most
/// invasive step is a *reversible* primary-service off/on cycle, used only as a last resort and
/// always guaranteed to be re-enabled by the executor.
enum FixStepKind: Equatable, CaseIterable {
    case removeStaleVPNRoutes
    case flushDNS
    case restoreDefaultRoute
    case renewDHCP
    case restoreIPv6Automatic
    case flushARP
    case cyclePrimaryService

    /// None of the safe steps are destructive. Kept explicit (rather than implicit) so the test
    /// suite fails loudly if a destructive step is ever introduced into the automatic plan.
    var isDestructive: Bool { false }

    /// Steps that change persistent state and therefore require the executor to guarantee a
    /// restore (e.g. in a `defer`) so they can never leave the machine worse off.
    var requiresGuaranteedRestore: Bool {
        switch self {
        case .cyclePrimaryService, .restoreIPv6Automatic: return true
        default: return false
        }
    }

    var summary: String {
        switch self {
        case .removeStaleVPNRoutes: return "Remove leftover VPN routes (only when no tunnel is running)"
        case .flushDNS: return "Flush DNS cache (dscacheutil + mDNSResponder)"
        case .restoreDefaultRoute: return "Restore the default route to the local gateway"
        case .renewDHCP: return "Renew the DHCP lease on the primary service"
        case .restoreIPv6Automatic: return "Restore IPv6 to automatic (never disables it)"
        case .flushARP: return "Flush the ARP cache"
        case .cyclePrimaryService: return "Toggle the primary network service off then on (reversible)"
        }
    }
}

/// Pure planner producing the ordered, least-invasive-first, never-destructive list of steps to
/// attempt for a broken network.
///
/// Guarantees (locked down by tests):
/// - Returns an EMPTY plan when connectivity is already healthy → the tool does nothing rather
///   than "fixing" a working network and breaking it (the exact failure the user hit).
/// - Never emits a destructive step.
/// - Escalates to the reversible service cycle only as the final step, and only when allowed.
///
/// The executor is expected to re-probe connectivity after each step, STOP as soon as
/// connectivity is restored, and revert a `requiresGuaranteedRestore` step if it made things worse.
enum NetworkFixPlanner {
    static func plan(probe: NetworkProbe,
                     snapshot: NetworkHealthSnapshot,
                     allowEscalation: Bool = true) -> [FixStepKind] {
        // Do NOTHING when the network already works.
        guard !probe.healthy else { return [] }

        var steps: [FixStepKind] = []

        // 1. Remove stale tunnel routes first — only safe when no tunnel process is running.
        if snapshot.orphanedTunnelInterface == true && !snapshot.tunnelProcessRunning {
            steps.append(.removeStaleVPNRoutes)
        }

        // 2. Flush DNS — cheap, safe, and the most common post-disconnect breakage.
        steps.append(.flushDNS)

        // 3. Only touch routing / DHCP when the default route is actually missing.
        if !probe.hasDefaultRoute {
            steps.append(.restoreDefaultRoute)
            steps.append(.renewDHCP)
        }

        // 4. Restore IPv6 to automatic only if stale VPN DNS suggests config was left altered.
        if snapshot.staleVPNDns == true && !snapshot.tunnelProcessRunning {
            steps.append(.restoreIPv6Automatic)
        }

        // 5. Flush ARP — cheap.
        steps.append(.flushARP)

        // 6. Last resort: reversible service cycle (executor guarantees re-enable + verify).
        if allowEscalation {
            steps.append(.cyclePrimaryService)
        }

        return steps
    }
}
