import XCTest
@testable import VPNFixHelper

/// Mirrors tests/safe-executor-check.swift for CI. Locks down the executor's stop-when-restored
/// sequencing — the guarantee that a healthy or recovering network is never over-fixed.
final class SafeFixExecutorTests: XCTestCase {

    /// Yields a scripted probe sequence, repeating the final value once exhausted.
    private final class ScriptedProbe {
        private var queue: [NetworkProbe]
        init(_ seq: [NetworkProbe]) { self.queue = seq }
        func next() -> NetworkProbe {
            if queue.count > 1 { return queue.removeFirst() }
            return queue.first ?? NetworkProbe(dnsResolves: false, hasDefaultRoute: false)
        }
    }

    private let unhealthy = NetworkProbe(dnsResolves: false, hasDefaultRoute: false)
    private let healthy = NetworkProbe(dnsResolves: true, hasDefaultRoute: true)

    func testHealthyAtStartRunsNothing() {
        let probe = ScriptedProbe([healthy])
        var ran: [FixStepKind] = []
        let outcome = SafeFixExecutor.run(
            plan: [.flushDNS, .flushARP, .cyclePrimaryService],
            probe: { probe.next() }, runStep: { ran.append($0) })
        XCTAssertTrue(ran.isEmpty)
        XCTAssertTrue(outcome.restored)
        XCTAssertTrue(outcome.ranSteps.isEmpty)
    }

    func testStopsAsSoonAsConnectivityReturns() {
        let probe = ScriptedProbe([unhealthy, healthy])
        var ran: [FixStepKind] = []
        let outcome = SafeFixExecutor.run(
            plan: [.flushDNS, .flushARP, .cyclePrimaryService],
            probe: { probe.next() }, runStep: { ran.append($0) })
        XCTAssertEqual(ran, [.flushDNS])
        XCTAssertTrue(outcome.restored)
        XCTAssertFalse(ran.contains(.cyclePrimaryService), "must never escalate once healthy")
    }

    func testRunsAllStepsWhenNeverHealthy() {
        let probe = ScriptedProbe([unhealthy])
        var ran: [FixStepKind] = []
        let outcome = SafeFixExecutor.run(
            plan: [.flushDNS, .restoreDefaultRoute, .flushARP],
            probe: { probe.next() }, runStep: { ran.append($0) })
        XCTAssertEqual(ran, [.flushDNS, .restoreDefaultRoute, .flushARP])
        XCTAssertFalse(outcome.restored)
    }

    func testRestoredReflectsFinalProbe() {
        let probe = ScriptedProbe([unhealthy, unhealthy, healthy])
        var ran: [FixStepKind] = []
        let outcome = SafeFixExecutor.run(
            plan: [.flushDNS, .flushARP],
            probe: { probe.next() }, runStep: { ran.append($0) })
        XCTAssertEqual(ran, [.flushDNS, .flushARP])
        XCTAssertTrue(outcome.restored)
    }

    func testEmptyPlanRunsNothing() {
        let probe = ScriptedProbe([unhealthy])
        var ran: [FixStepKind] = []
        let outcome = SafeFixExecutor.run(plan: [], probe: { probe.next() }, runStep: { ran.append($0) })
        XCTAssertTrue(ran.isEmpty)
        XCTAssertFalse(outcome.restored)
    }
}
