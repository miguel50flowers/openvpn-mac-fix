import XCTest

/// Tests for the stateful coordinator that remembers the last known VPN state and drives
/// the auto-fix. These exercise the wiring (last-known-state + cooldown) with injected
/// fakes — no netstat, no clock, no real script — so the connect/disconnect behavior is
/// verified deterministically.
final class AutoFixCoordinatorTests: XCTestCase {

    private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a coordinator whose state readings come from a fixed sequence (clamped at the
    /// end), counting how many times the fix is invoked.
    private func makeCoordinator(states: [VPNState],
                                 tunnelRunning: Bool = false,
                                 now: @escaping () -> Date,
                                 fixCount: @escaping () -> Void) -> AutoFixCoordinator {
        var index = 0
        return AutoFixCoordinator(
            policy: AutoFixPolicy(cooldown: 30),
            stateProvider: {
                let state = states[min(index, states.count - 1)]
                index += 1
                return state
            },
            tunnelProcessRunning: { tunnelRunning },
            runFix: { completion in fixCount(); completion(true, "ok") },
            now: now,
            log: { _ in },
            initialState: .unknown
        )
    }

    func testFiresExactlyOnceOnConnectedThenDisconnected() {
        var fixes = 0
        let coord = makeCoordinator(states: [.connected, .disconnected, .disconnected],
                                    now: { self.fixedNow }, fixCount: { fixes += 1 })
        coord.evaluate() // unknown → connected
        XCTAssertEqual(fixes, 0)
        coord.evaluate() // connected → disconnected
        XCTAssertEqual(fixes, 1)
        coord.evaluate() // disconnected → disconnected
        XCTAssertEqual(fixes, 1)
    }

    func testSecondDisconnectWithinCooldownDoesNotFireAgain() {
        var fixes = 0
        let coord = makeCoordinator(states: [.connected, .disconnected, .connected, .disconnected],
                                    now: { self.fixedNow }, fixCount: { fixes += 1 })
        coord.evaluate() // → connected
        coord.evaluate() // → disconnected (fix #1)
        coord.evaluate() // → connected
        coord.evaluate() // → disconnected, but within cooldown
        XCTAssertEqual(fixes, 1)
    }

    func testSecondDisconnectAfterCooldownFiresAgain() {
        var fixes = 0
        var clock = fixedNow
        let coord = makeCoordinator(states: [.connected, .disconnected, .connected, .disconnected],
                                    now: { clock }, fixCount: { fixes += 1 })
        coord.evaluate() // → connected
        coord.evaluate() // → disconnected (fix #1)
        clock = fixedNow.addingTimeInterval(40) // beyond the 30s cooldown
        coord.evaluate() // → connected
        coord.evaluate() // → disconnected (fix #2)
        XCTAssertEqual(fixes, 2)
    }

    func testNoFixWhileTunnelProcessRunning() {
        var fixes = 0
        let coord = makeCoordinator(states: [.connected, .disconnected],
                                    tunnelRunning: true,
                                    now: { self.fixedNow }, fixCount: { fixes += 1 })
        coord.evaluate()
        coord.evaluate()
        XCTAssertEqual(fixes, 0)
    }

    func testSeedLetsFirstObservedDisconnectFire() {
        var current: VPNState = .connected
        var fixes = 0
        let coord = AutoFixCoordinator(
            policy: AutoFixPolicy(cooldown: 30),
            stateProvider: { current },
            tunnelProcessRunning: { false },
            runFix: { completion in fixes += 1; completion(true, "ok") },
            now: { self.fixedNow },
            log: { _ in },
            initialState: .unknown
        )
        coord.seed()            // baseline = .connected
        current = .disconnected
        coord.evaluate()        // connected → disconnected
        XCTAssertEqual(fixes, 1)
    }

    func testEvaluateReturnsDecision() {
        let coord = makeCoordinator(states: [.connected, .disconnected],
                                    now: { self.fixedNow }, fixCount: { })
        XCTAssertEqual(coord.evaluate(), .skip(.noDisconnectTransition)) // unknown → connected
        XCTAssertEqual(coord.evaluate(), .runFix)                        // connected → disconnected
    }
}
