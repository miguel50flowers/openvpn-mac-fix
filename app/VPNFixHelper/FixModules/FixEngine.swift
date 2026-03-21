import Foundation

/// Coordinates all fix modules — dispatches per-client fixes and aggregates results.
final class FixEngine {
    private let modules: [VPNClientType: VPNFixModule]
    private let commonFix = CommonFixModule()

    init() {
        let allModules: [VPNFixModule] = [
            OpenVPNFixModule(),
            WireGuardFixModule(),
            KillSwitchFixModule(),
            ProxyFixModule(),
            AnyConnectFixModule(),
            GlobalProtectFixModule(),
            FortiClientFixModule(),
        ]
        var map: [VPNClientType: VPNFixModule] = [:]
        for module in allModules {
            map[module.clientType] = module
        }
        self.modules = map
    }

    func fixClient(_ type: VPNClientType, issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        guard !issues.isEmpty else {
            completion(true, "No issues to fix for \(type.displayName)")
            return
        }

        HelperLogger.shared.info("[FixEngine] Fixing \(type.displayName) (\(issues.count) issues)")

        // Run client-specific fix if available
        if let module = modules[type] {
            module.fix(issues: issues) { success, message in
                // Always run common fix after client-specific fix
                self.commonFix.fix(issues: issues) { commonSuccess, commonMessage in
                    let finalSuccess = success && commonSuccess
                    HelperLogger.shared.info("[FixEngine] \(type.displayName) fix done: \(finalSuccess)")
                    completion(finalSuccess, message)
                }
            }
        } else {
            // No client-specific module — just run common fix
            commonFix.fix(issues: issues) { success, message in
                HelperLogger.shared.info("[FixEngine] \(type.displayName) common fix done: \(success)")
                completion(success, message)
            }
        }
    }

    func fixAll(statuses: [VPNClientStatus], completion: @escaping (Bool, String) -> Void) {
        let clientsWithIssues = statuses.filter { $0.hasIssues }
        guard !clientsWithIssues.isEmpty else {
            completion(true, "No issues detected")
            return
        }

        HelperLogger.shared.info("[FixEngine] Fixing all: \(clientsWithIssues.count) clients with issues")

        let group = DispatchGroup()
        var allSuccess = true
        var messages: [String] = []
        let allIssues = clientsWithIssues.flatMap { $0.detectedIssues }

        // Run client-specific fixes in parallel (without CommonFixModule)
        for status in clientsWithIssues {
            group.enter()
            if let module = modules[status.clientType] {
                module.fix(issues: status.detectedIssues) { success, message in
                    if !success { allSuccess = false }
                    messages.append("\(status.clientType.displayName): \(message)")
                    group.leave()
                }
            } else {
                group.leave()
            }
        }

        // Run CommonFixModule once after all client-specific fixes complete
        group.notify(queue: .global()) { [self] in
            commonFix.fix(issues: allIssues) { commonSuccess, commonMessage in
                if !commonSuccess { allSuccess = false }
                messages.append("Common: \(commonMessage)")
                let summary = messages.joined(separator: "; ")
                HelperLogger.shared.info("[FixEngine] Fix all complete: success=\(allSuccess)")
                completion(allSuccess, summary)
            }
        }
    }
}
