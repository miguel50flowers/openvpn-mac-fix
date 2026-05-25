import Foundation

/// Pure orchestration of a safe, sequential network-fix run.
///
/// The dangerous part of the old "Fix Everything" was not any single command — it was running a
/// fixed batch of changes *in parallel, without checking whether they were needed or whether they
/// helped*. This executor inverts that: it probes connectivity before each step and **stops the
/// instant the network is healthy**, so a working network is never touched and a network that
/// recovers part-way through is never over-fixed (the exact failure mode the user hit).
///
/// It is intentionally free of any system calls: the real connectivity probe and the per-step
/// command runner are injected by the helper, which makes this stop-when-restored sequencing
/// unit-testable without sudo, `networksetup`, or a live network.
enum SafeFixExecutor {
    struct Outcome: Equatable {
        let ranSteps: [FixStepKind]
        let restored: Bool
    }

    /// Runs `plan` in order. Before each step it probes; if connectivity is already healthy it
    /// stops immediately. After the loop it probes once more so `restored` reflects the effect of
    /// the final step too.
    ///
    /// - Parameters:
    ///   - plan: the ordered, never-destructive steps from `NetworkFixPlanner`.
    ///   - probe: live connectivity probe (called between steps; keep it cheap).
    ///   - runStep: performs one step's real work (already-safe fix modules in the helper).
    static func run(plan: [FixStepKind],
                    probe: () -> NetworkProbe,
                    runStep: (FixStepKind) -> Void) -> Outcome {
        var ran: [FixStepKind] = []
        for step in plan {
            if probe().healthy {
                return Outcome(ranSteps: ran, restored: true)
            }
            runStep(step)
            ran.append(step)
        }
        return Outcome(ranSteps: ran, restored: probe().healthy)
    }
}
