import Foundation

// Standalone verification for the network-health classifier and the SAFE fix planner.
//
// Why this exists: the app failed to DETECT a broken network after a VPN disconnect, and its
// "Fix Everything" actively BROKE connectivity (left an interface down / IPv6 off). The decision
// logic is extracted into pure, dependency-free types in app/Shared/ so the two guarantees that
// matter can be locked down without Xcode, sudo, or touching the network:
//   1. A broken network (no route / no DNS / orphaned tunnel) is classified as a real issue.
//   2. The auto fix plan is NEVER destructive and does NOTHING when connectivity is already fine.
//
// The authoritative suites live in app/VPNFixTests/*Tests.swift (XCTest, CI). This mirror covers
// the critical cases and is run by tests/smoke-test.sh on any machine with swiftc.

@main
struct NetworkLogicCheck {
    static var checks = 0
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        checks += 1
        if condition { print("  ✓ \(message)") }
        else { failures += 1; print("  ✗ FAIL: \(message)") }
    }

    static func main() {
        testClassifier()
        testPlannerSafety()
        testPlannerOrdering()

        print("")
        print("\(checks - failures)/\(checks) checks passed")
        if failures > 0 { print("NETWORK LOGIC CHECK FAILED (\(failures) failing)"); exit(1) }
        print("NETWORK LOGIC CHECK PASSED")
        exit(0)
    }

    private static func has(_ issues: [VPNIssue], _ type: VPNIssue.IssueType) -> Bool {
        issues.contains { $0.type == type }
    }

    // MARK: - NetworkHealthClassifier

    static func testClassifier() {
        print("NetworkHealthClassifier:")

        let healthy = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: true)
        expect(NetworkHealthClassifier.issues(from: healthy).isEmpty,
               "healthy network → no issues")

        let noRoute = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: false)
        expect(has(NetworkHealthClassifier.issues(from: noRoute), .noDefaultRoute),
               "missing default route → noDefaultRoute")
        expect(!has(NetworkHealthClassifier.issues(from: noRoute), .noConnectivity),
               "missing route only (DNS ok) → not noConnectivity")

        let noDNS = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true)
        expect(has(NetworkHealthClassifier.issues(from: noDNS), .dnsFailure),
               "DNS does not resolve → dnsFailure")

        let dead = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false)
        let deadIssues = NetworkHealthClassifier.issues(from: dead)
        expect(has(deadIssues, .noConnectivity), "no route + no DNS → noConnectivity")
        expect(!has(deadIssues, .noDefaultRoute) && !has(deadIssues, .dnsFailure),
               "noConnectivity subsumes the individual route/DNS issues")

        let orphan = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: true,
                                           orphanedTunnelInterface: true, tunnelProcessRunning: false)
        expect(has(NetworkHealthClassifier.issues(from: orphan), .orphanedInterface),
               "orphaned utun/ppp interface (no tunnel process) → orphanedInterface")

        let liveTunnel = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: true,
                                               orphanedTunnelInterface: true, tunnelProcessRunning: true)
        expect(!has(NetworkHealthClassifier.issues(from: liveTunnel), .orphanedInterface),
               "utun present WITH a live tunnel process → not orphaned (expected)")

        let staleDNS = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true,
                                             staleVPNDns: true, tunnelProcessRunning: false)
        expect(has(NetworkHealthClassifier.issues(from: staleDNS), .dnsLeak),
               "stale VPN DNS while no tunnel running → dnsLeak")

        let unknown = NetworkHealthSnapshot()  // everything nil = couldn't measure
        expect(NetworkHealthClassifier.issues(from: unknown).isEmpty,
               "nothing measurable → no false-positive issues")
    }

    // MARK: - NetworkFixPlanner safety (the core guarantee)

    static func testPlannerSafety() {
        print("NetworkFixPlanner (safety):")

        let healthy = NetworkProbe(dnsResolves: true, hasDefaultRoute: true)
        expect(NetworkFixPlanner.plan(probe: healthy, snapshot: NetworkHealthSnapshot()).isEmpty,
               "already healthy → empty plan (do NOTHING, never make it worse)")

        let dead = NetworkProbe(dnsResolves: false, hasDefaultRoute: false)
        let snap = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false)

        // Across a matrix of snapshots, NO plan may ever contain a destructive step.
        let snapshots = [
            NetworkHealthSnapshot(),
            snap,
            NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true, orphanedTunnelInterface: true, tunnelProcessRunning: false),
            NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false, staleVPNDns: true, tunnelProcessRunning: false),
        ]
        var anyDestructive = false
        for s in snapshots {
            for escalate in [true, false] {
                let plan = NetworkFixPlanner.plan(probe: dead, snapshot: s, allowEscalation: escalate)
                if plan.contains(where: { $0.isDestructive }) { anyDestructive = true }
            }
        }
        expect(!anyDestructive, "no auto plan ever contains a destructive step (no ifconfig down, no setv6off, no pfctl -d, no plist delete)")

        let escalated = NetworkFixPlanner.plan(probe: dead, snapshot: snap, allowEscalation: true)
        expect(escalated.last == .cyclePrimaryService,
               "service cycle (reversible escalation) is the LAST resort")

        let noEscalation = NetworkFixPlanner.plan(probe: dead, snapshot: snap, allowEscalation: false)
        expect(!noEscalation.contains(.cyclePrimaryService),
               "allowEscalation=false → never cycle the service")
    }

    // MARK: - NetworkFixPlanner ordering / minimality

    static func testPlannerOrdering() {
        print("NetworkFixPlanner (ordering):")
        let dead = NetworkProbe(dnsResolves: false, hasDefaultRoute: false)

        let orphan = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false,
                                           orphanedTunnelInterface: true, tunnelProcessRunning: false)
        let plan = NetworkFixPlanner.plan(probe: dead, snapshot: orphan)
        if let removeIdx = plan.firstIndex(of: .removeStaleVPNRoutes),
           let dnsIdx = plan.firstIndex(of: .flushDNS) {
            expect(removeIdx < dnsIdx, "remove stale VPN routes before flushing DNS")
        } else {
            expect(false, "plan should include removeStaleVPNRoutes and flushDNS when orphaned + dead")
        }
        expect(plan.contains(.restoreDefaultRoute), "missing route → plan restores the default route")

        let dnsOnly = NetworkProbe(dnsResolves: false, hasDefaultRoute: true)
        let dnsPlan = NetworkFixPlanner.plan(probe: dnsOnly, snapshot: NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true))
        expect(dnsPlan.contains(.flushDNS), "DNS broken but route ok → flush DNS")
        expect(!dnsPlan.contains(.restoreDefaultRoute), "route is fine → do NOT touch routing")
    }
}
