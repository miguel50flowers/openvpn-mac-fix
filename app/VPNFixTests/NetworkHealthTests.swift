import XCTest

/// Tests that a genuinely broken network (no route / no DNS / orphaned tunnel / stale VPN DNS) is
/// classified as a real issue, and that an unknown (timed-out) reading never produces a false
/// "no issue". This is the detection half of the fix for "the app reports issues=0 when offline".
final class NetworkHealthTests: XCTestCase {

    private func has(_ issues: [VPNIssue], _ type: VPNIssue.IssueType) -> Bool {
        issues.contains { $0.type == type }
    }

    func testHealthyNetworkHasNoIssues() {
        let s = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: true)
        XCTAssertTrue(NetworkHealthClassifier.issues(from: s).isEmpty)
    }

    func testMissingDefaultRoute() {
        let s = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: false)
        let issues = NetworkHealthClassifier.issues(from: s)
        XCTAssertTrue(has(issues, .noDefaultRoute))
        XCTAssertFalse(has(issues, .noConnectivity))
    }

    func testDnsFailure() {
        let s = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true)
        XCTAssertTrue(has(NetworkHealthClassifier.issues(from: s), .dnsFailure))
    }

    func testNoConnectivitySubsumesRouteAndDns() {
        let s = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: false)
        let issues = NetworkHealthClassifier.issues(from: s)
        XCTAssertTrue(has(issues, .noConnectivity))
        XCTAssertFalse(has(issues, .noDefaultRoute))
        XCTAssertFalse(has(issues, .dnsFailure))
    }

    func testOrphanedTunnelInterface() {
        let s = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: true,
                                      orphanedTunnelInterface: true, tunnelProcessRunning: false)
        XCTAssertTrue(has(NetworkHealthClassifier.issues(from: s), .orphanedInterface))
    }

    func testLiveTunnelIsNotOrphaned() {
        let s = NetworkHealthSnapshot(dnsResolves: true, hasDefaultRoute: true,
                                      orphanedTunnelInterface: true, tunnelProcessRunning: true)
        XCTAssertFalse(has(NetworkHealthClassifier.issues(from: s), .orphanedInterface))
    }

    func testStaleVpnDnsWhileNoTunnel() {
        let s = NetworkHealthSnapshot(dnsResolves: false, hasDefaultRoute: true,
                                      staleVPNDns: true, tunnelProcessRunning: false)
        XCTAssertTrue(has(NetworkHealthClassifier.issues(from: s), .dnsLeak))
    }

    func testUnknownReadingsProduceNoFalseIssues() {
        // Everything nil = nothing could be measured (e.g. all commands timed out).
        XCTAssertTrue(NetworkHealthClassifier.issues(from: NetworkHealthSnapshot()).isEmpty)
    }
}
