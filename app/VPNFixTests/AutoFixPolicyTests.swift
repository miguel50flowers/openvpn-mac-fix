import XCTest

/// Tests for the auto-fix decision logic. The first test is the regression guard for the
/// core bug: a genuine connected→disconnected transition must run the fix. The old helper
/// could not satisfy this because it compared two readings both taken after the disconnect.
final class AutoFixPolicyTests: XCTestCase {

    private let policy = AutoFixPolicy(cooldown: 30)
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testConnectedToDisconnectedRunsFix() {
        let decision = policy.decide(previous: .connected, current: .disconnected,
                                     lastFix: .distantPast, now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .runFix)
    }

    func testDisconnectedToDisconnectedDoesNotFix() {
        // Exactly the failure mode of the old code: two late reads, both .disconnected.
        let decision = policy.decide(previous: .disconnected, current: .disconnected,
                                     lastFix: .distantPast, now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .skip(.noDisconnectTransition))
    }

    func testConnectedToConnectedDoesNotFix() {
        let decision = policy.decide(previous: .connected, current: .connected,
                                     lastFix: .distantPast, now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .skip(.noDisconnectTransition))
    }

    func testReconnectDoesNotFix() {
        let decision = policy.decide(previous: .disconnected, current: .connected,
                                     lastFix: .distantPast, now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .skip(.noDisconnectTransition))
    }

    func testTransitionWithinCooldownIsSkipped() {
        let decision = policy.decide(previous: .connected, current: .disconnected,
                                     lastFix: now.addingTimeInterval(-10), now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .skip(.cooldownActive))
    }

    func testTransitionAfterCooldownRunsFix() {
        let decision = policy.decide(previous: .connected, current: .disconnected,
                                     lastFix: now.addingTimeInterval(-31), now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .runFix)
    }

    func testTransitionExactlyAtCooldownBoundaryRunsFix() {
        // elapsed == cooldown is not "< cooldown", so the fix is allowed.
        let decision = policy.decide(previous: .connected, current: .disconnected,
                                     lastFix: now.addingTimeInterval(-30), now: now, tunnelProcessRunning: false)
        XCTAssertEqual(decision, .runFix)
    }

    func testTransitionWithTunnelProcessRunningIsSkipped() {
        let decision = policy.decide(previous: .connected, current: .disconnected,
                                     lastFix: .distantPast, now: now, tunnelProcessRunning: true)
        XCTAssertEqual(decision, .skip(.tunnelProcessRunning))
    }

    func testNoTransitionTakesPrecedenceOverOtherGuards() {
        // Even with cooldown elapsed and a running process, a non-transition is just skipped.
        let decision = policy.decide(previous: .connected, current: .connected,
                                     lastFix: now, now: now, tunnelProcessRunning: true)
        XCTAssertEqual(decision, .skip(.noDisconnectTransition))
    }
}
