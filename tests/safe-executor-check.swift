// RED→GREEN harness for the pure SafeFixExecutor orchestration.
//
// Build & run (from repo root):
//   swiftc -parse-as-library \
//     app/Shared/VPNIssue.swift app/Shared/NetworkHealth.swift \
//     app/Shared/NetworkFixPlanner.swift app/Shared/SafeFixExecutor.swift \
//     tests/safe-executor-check.swift -o /tmp/safe-executor-check && /tmp/safe-executor-check
//
// Verifies the executor's only real responsibilities: run steps in order, re-probe between them,
// and STOP the instant connectivity returns so a recovering network is never over-fixed.

import Foundation

private var failures = 0
private func check(_ cond: Bool, _ name: String) {
    if cond { print("  ok   \(name)") } else { print("  FAIL \(name)"); failures += 1 }
}

/// Probe stub that yields a scripted sequence, repeating the final value once exhausted.
private final class ScriptedProbe {
    private var queue: [NetworkProbe]
    private(set) var calls = 0
    init(_ seq: [NetworkProbe]) { self.queue = seq }
    func next() -> NetworkProbe {
        calls += 1
        if queue.count > 1 { return queue.removeFirst() }
        return queue.first ?? NetworkProbe(dnsResolves: false, hasDefaultRoute: false)
    }
}

private let unhealthy = NetworkProbe(dnsResolves: false, hasDefaultRoute: false)
private let healthy = NetworkProbe(dnsResolves: true, hasDefaultRoute: true)

@main
struct SafeExecutorCheck {
    static func main() {
        print("SafeFixExecutor checks:")

        // 1. Healthy from the very first probe → run NOTHING, report restored.
        do {
            let probe = ScriptedProbe([healthy])
            var ran: [FixStepKind] = []
            let outcome = SafeFixExecutor.run(
                plan: [.flushDNS, .flushARP, .cyclePrimaryService],
                probe: { probe.next() }, runStep: { ran.append($0) })
            check(ran.isEmpty, "healthy at start runs no steps")
            check(outcome.restored, "healthy at start reports restored")
            check(outcome.ranSteps.isEmpty, "healthy at start outcome has no ranSteps")
        }

        // 2. Becomes healthy after the first step → stop before the rest.
        do {
            let probe = ScriptedProbe([unhealthy, healthy]) // iter1 unhealthy → run; iter2 healthy → stop
            var ran: [FixStepKind] = []
            let outcome = SafeFixExecutor.run(
                plan: [.flushDNS, .flushARP, .cyclePrimaryService],
                probe: { probe.next() }, runStep: { ran.append($0) })
            check(ran == [.flushDNS], "stops after the step that restores connectivity")
            check(outcome.restored, "reports restored when connectivity returns mid-plan")
            check(!ran.contains(.cyclePrimaryService), "never escalates to service cycle once healthy")
        }

        // 3. Never healthy → run every step, report not restored.
        do {
            let probe = ScriptedProbe([unhealthy])
            var ran: [FixStepKind] = []
            let outcome = SafeFixExecutor.run(
                plan: [.flushDNS, .restoreDefaultRoute, .flushARP],
                probe: { probe.next() }, runStep: { ran.append($0) })
            check(ran == [.flushDNS, .restoreDefaultRoute, .flushARP], "runs all steps when never healthy")
            check(!outcome.restored, "reports not restored when still broken at the end")
        }

        // 4. Last step fixes it → restored reflects the FINAL probe, all steps ran.
        do {
            let probe = ScriptedProbe([unhealthy, unhealthy, healthy]) // iter1,2 unhealthy; final probe healthy
            var ran: [FixStepKind] = []
            let outcome = SafeFixExecutor.run(
                plan: [.flushDNS, .flushARP],
                probe: { probe.next() }, runStep: { ran.append($0) })
            check(ran == [.flushDNS, .flushARP], "runs both steps when each pre-probe is unhealthy")
            check(outcome.restored, "final probe healthy ⇒ restored even if detected only at the end")
        }

        // 5. Empty plan → run nothing; restored mirrors a single probe.
        do {
            let probe = ScriptedProbe([unhealthy])
            var ran: [FixStepKind] = []
            let outcome = SafeFixExecutor.run(plan: [], probe: { probe.next() }, runStep: { ran.append($0) })
            check(ran.isEmpty && !outcome.restored, "empty plan runs nothing and mirrors the probe")
        }

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
