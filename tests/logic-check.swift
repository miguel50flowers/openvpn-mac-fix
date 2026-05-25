import Foundation

// Standalone logic verification for the VPN-Fix core decision logic.
//
// Why this exists: the privileged-helper core (VPN state classification + the
// connected→disconnected auto-fix decision) is the part that "did not work" when
// connecting/disconnecting. It is now extracted into pure, dependency-free types in
// app/Shared/ so it can be verified WITHOUT Xcode, sudo, or a real VPN.
//
// Run via:  tests/smoke-test.sh   (or compile directly, see that script)
// The authoritative, comprehensive suite lives in app/VPNFixTests/*Tests.swift and
// runs under XCTest in CI; this mirror covers the regression-critical cases so the
// core can be smoke-tested on any machine with `swiftc`.

@main
struct LogicCheck {
    static var checks = 0
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        checks += 1
        if condition {
            print("  ✓ \(message)")
        } else {
            failures += 1
            print("  ✗ FAIL: \(message)")
        }
    }

    static func main() {
        testClassifier()
        testPolicy()
        testCoordinator()

        print("")
        print("\(checks - failures)/\(checks) checks passed")
        if failures > 0 {
            print("LOGIC CHECK FAILED (\(failures) failing)")
            exit(1)
        }
        print("LOGIC CHECK PASSED")
        exit(0)
    }

    // MARK: - VPNStateClassifier

    static func testClassifier() {
        print("VPNStateClassifier:")

        let openVPNConnected = """
        Routing tables

        Internet:
        Destination        Gateway            Flags        Netif Expire
        default            192.168.1.1        UGScg          en0
        0/1                10.8.0.1           UGScg        utun4
        128.0/1            10.8.0.1           UGScg        utun4
        10.8.0.1           10.8.0.5           UH           utun4
        """
        expect(VPNStateClassifier.classify(netstatOutput: openVPNConnected) == .connected,
               "OpenVPN split routes (0/1 + 128.0/1 via utun) → connected")

        let cleanNoVPN = """
        Routing tables

        Internet:
        Destination        Gateway            Flags        Netif Expire
        default            192.168.1.1        UGScg          en0
        127                127.0.0.1          UCS            lo0
        192.168.1.0/24     link#11            UCS            en0
        fe80::/64          link#15            UCI          utun0
        """
        expect(VPNStateClassifier.classify(netstatOutput: cleanNoVPN) == .disconnected,
               "no VPN routes (benign system utun0 present) → disconnected")

        let partialOpenVPN = """
        default            192.168.1.1        UGScg          en0
        0/1                10.8.0.1           UGScg        utun4
        """
        expect(VPNStateClassifier.classify(netstatOutput: partialOpenVPN) == .disconnected,
               "only 0/1 (no 128.0/1) → not treated as connected")

        let wireGuard = "default            10.96.0.1          UGScg        utun3"
        expect(VPNStateClassifier.classify(netstatOutput: wireGuard) == .connected,
               "default route via utun (WireGuard) → connected")

        let ppp = "default            10.0.8.1           UGSc         ppp0"
        expect(VPNStateClassifier.classify(netstatOutput: ppp) == .connected,
               "default via ppp0 → connected")

        let globalProtect = "default            10.20.0.1          UGSc         gpd0"
        expect(VPNStateClassifier.classify(netstatOutput: globalProtect) == .connected,
               "default via gpd0 (GlobalProtect) → connected")

        let ipsec = "default            10.1.2.3           UGSc        ipsec0"
        expect(VPNStateClassifier.classify(netstatOutput: ipsec) == .connected,
               "ipsec interface → connected")

        expect(VPNStateClassifier.classify(netstatOutput: "") == .disconnected,
               "empty netstat output → disconnected")
    }

    // MARK: - AutoFixPolicy

    static func testPolicy() {
        print("AutoFixPolicy:")
        let policy = AutoFixPolicy(cooldown: 30)
        let now = Date(timeIntervalSince1970: 1_000_000)

        expect(policy.decide(previous: .connected, current: .disconnected,
                             lastFix: .distantPast, now: now, tunnelProcessRunning: false) == .runFix,
               "connected→disconnected, no cooldown, no tunnel proc → runFix (THE regression)")

        expect(policy.decide(previous: .disconnected, current: .disconnected,
                             lastFix: .distantPast, now: now, tunnelProcessRunning: false) == .skip(.noDisconnectTransition),
               "disconnected→disconnected → skip (the old buggy two-late-reads case)")

        expect(policy.decide(previous: .connected, current: .connected,
                             lastFix: .distantPast, now: now, tunnelProcessRunning: false) == .skip(.noDisconnectTransition),
               "connected→connected → skip")

        expect(policy.decide(previous: .disconnected, current: .connected,
                             lastFix: .distantPast, now: now, tunnelProcessRunning: false) == .skip(.noDisconnectTransition),
               "reconnect (disconnected→connected) → skip")

        expect(policy.decide(previous: .connected, current: .disconnected,
                             lastFix: now.addingTimeInterval(-10), now: now, tunnelProcessRunning: false) == .skip(.cooldownActive),
               "transition within cooldown (10s < 30s) → skip(cooldownActive)")

        expect(policy.decide(previous: .connected, current: .disconnected,
                             lastFix: now.addingTimeInterval(-31), now: now, tunnelProcessRunning: false) == .runFix,
               "transition after cooldown (31s > 30s) → runFix")

        expect(policy.decide(previous: .connected, current: .disconnected,
                             lastFix: .distantPast, now: now, tunnelProcessRunning: true) == .skip(.tunnelProcessRunning),
               "transition but tunnel process running → skip(tunnelProcessRunning)")

        expect(policy.decide(previous: .connected, current: .connected,
                             lastFix: now, now: now, tunnelProcessRunning: true) == .skip(.noDisconnectTransition),
               "no-transition check takes precedence over cooldown/process")
    }

    // MARK: - AutoFixCoordinator

    static func testCoordinator() {
        print("AutoFixCoordinator:")
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)

        // Fires exactly once across connected → disconnected (and not again).
        do {
            let sequence: [VPNState] = [.connected, .disconnected, .disconnected]
            var index = 0
            var fixCount = 0
            let coord = AutoFixCoordinator(
                policy: AutoFixPolicy(cooldown: 30),
                stateProvider: { let s = sequence[min(index, sequence.count - 1)]; index += 1; return s },
                tunnelProcessRunning: { false },
                runFix: { completion in fixCount += 1; completion(true, "ok") },
                now: { fixedNow },
                log: { _ in },
                initialState: .unknown
            )
            _ = coord.evaluate() // unknown → connected
            expect(fixCount == 0, "no fix on initial unknown→connected")
            _ = coord.evaluate() // connected → disconnected
            expect(fixCount == 1, "fix fires on connected→disconnected")
            _ = coord.evaluate() // disconnected → disconnected
            expect(fixCount == 1, "no second fix while staying disconnected")
        }

        // Cooldown blocks a rapid second disconnect.
        do {
            let sequence: [VPNState] = [.connected, .disconnected, .connected, .disconnected]
            var index = 0
            var fixCount = 0
            let coord = AutoFixCoordinator(
                policy: AutoFixPolicy(cooldown: 30),
                stateProvider: { let s = sequence[min(index, sequence.count - 1)]; index += 1; return s },
                tunnelProcessRunning: { false },
                runFix: { completion in fixCount += 1; completion(true, "ok") },
                now: { fixedNow }, // clock does not advance → still within cooldown
                log: { _ in },
                initialState: .unknown
            )
            _ = coord.evaluate() // → connected
            _ = coord.evaluate() // → disconnected (fix #1)
            _ = coord.evaluate() // → connected
            _ = coord.evaluate() // → disconnected, but within cooldown
            expect(fixCount == 1, "second disconnect within cooldown does not fix again")
        }

        // Active tunnel process blocks the fix.
        do {
            let sequence: [VPNState] = [.connected, .disconnected]
            var index = 0
            var fixCount = 0
            let coord = AutoFixCoordinator(
                policy: AutoFixPolicy(cooldown: 30),
                stateProvider: { let s = sequence[min(index, sequence.count - 1)]; index += 1; return s },
                tunnelProcessRunning: { true },
                runFix: { completion in fixCount += 1; completion(true, "ok") },
                now: { fixedNow },
                log: { _ in },
                initialState: .unknown
            )
            _ = coord.evaluate()
            _ = coord.evaluate()
            expect(fixCount == 0, "no fix while a VPN tunnel process is still running")
        }

        // seed() captures the pre-change state so the very next disconnect is detected.
        do {
            var current: VPNState = .connected
            var fixCount = 0
            let coord = AutoFixCoordinator(
                policy: AutoFixPolicy(cooldown: 30),
                stateProvider: { current },
                tunnelProcessRunning: { false },
                runFix: { completion in fixCount += 1; completion(true, "ok") },
                now: { fixedNow },
                log: { _ in },
                initialState: .unknown
            )
            coord.seed()            // lastKnown = .connected
            current = .disconnected
            _ = coord.evaluate()    // connected → disconnected
            expect(fixCount == 1, "seed() lets the first observed disconnect trigger a fix")
        }
    }
}
