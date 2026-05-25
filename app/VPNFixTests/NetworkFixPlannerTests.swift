import XCTest

/// Tests the SAFETY guarantees of the network fix planner — the core defense against the tool
/// breaking the internet: it does nothing when healthy, never emits a destructive step, and only
/// escalates to a reversible service cycle as a last resort.
final class NetworkFixPlannerTests: XCTestCase {

    private let dead = NetworkProbe(dnsResolves: false, hasDefaultRoute: false)

    func testHealthyProducesEmptyPlan() {
        let healthy = NetworkProbe(dnsResolves: true, hasDefaultRoute: true)
        XCTAssertEqual(NetworkFixPlanner.plan(probe: healthy, snapshot: NetworkHealthSnapshot()), [])
    }

    func testNoPlanIsEverDestructive() {
        let snapshots = [
            NetworkHealthSnapshot(),
            NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false),
            NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true,
                                  orphanedTunnelInterface: true, tunnelProcessRunning: false),
            NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false,
                                  staleVPNDns: true, tunnelProcessRunning: false),
        ]
        for s in snapshots {
            for escalate in [true, false] {
                let plan = NetworkFixPlanner.plan(probe: dead, snapshot: s, allowEscalation: escalate)
                XCTAssertFalse(plan.contains { $0.isDestructive },
                               "plan must never contain a destructive step")
            }
        }
    }

    func testServiceCycleIsLastResort() {
        let plan = NetworkFixPlanner.plan(probe: dead, snapshot: NetworkHealthSnapshot(), allowEscalation: true)
        XCTAssertEqual(plan.last, .cyclePrimaryService)
    }

    func testNoEscalationNeverCyclesService() {
        let plan = NetworkFixPlanner.plan(probe: dead, snapshot: NetworkHealthSnapshot(), allowEscalation: false)
        XCTAssertFalse(plan.contains(.cyclePrimaryService))
    }

    func testStaleRoutesRemovedBeforeDnsFlush() {
        let orphan = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false,
                                           orphanedTunnelInterface: true, tunnelProcessRunning: false)
        let plan = NetworkFixPlanner.plan(probe: dead, snapshot: orphan)
        let removeIdx = plan.firstIndex(of: .removeStaleVPNRoutes)
        let dnsIdx = plan.firstIndex(of: .flushDNS)
        XCTAssertNotNil(removeIdx)
        XCTAssertNotNil(dnsIdx)
        if let r = removeIdx, let d = dnsIdx { XCTAssertLessThan(r, d) }
    }

    func testRestoresRouteOnlyWhenMissing() {
        let dnsOnly = NetworkProbe(dnsResolves: false, hasDefaultRoute: true)
        let plan = NetworkFixPlanner.plan(probe: dnsOnly,
                                          snapshot: NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true))
        XCTAssertTrue(plan.contains(.flushDNS))
        XCTAssertFalse(plan.contains(.restoreDefaultRoute), "route is fine → must not touch routing")
    }
}
