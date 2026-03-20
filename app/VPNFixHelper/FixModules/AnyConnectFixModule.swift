import Foundation

/// Fixes Cisco AnyConnect — restarts vpnagentd, clears search domains, kills acwebhelper.
final class AnyConnectFixModule: VPNFixModule {
    let clientType: VPNClientType = .ciscoAnyConnect

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[AnyConnectFix] Fixing AnyConnect issues")

        var steps: [String] = []

        // Kill acwebhelper if running
        if DetectionUtilities.isProcessRunning("acwebhelper") {
            _ = DetectionUtilities.runCommand("/usr/bin/killall", arguments: ["acwebhelper"])
            steps.append("Killed acwebhelper")
        }

        // Fix DNS issues
        let dnsIssues = issues.filter { $0.type == .dnsLeak }
        if !dnsIssues.isEmpty {
            clearSearchDomains()
            steps.append("Cleared corporate DNS/search domains")
        }

        // Restart vpnagentd if it's stuck
        let daemonIssues = issues.filter { $0.type == .daemonPersistence }
        if !daemonIssues.isEmpty {
            _ = DetectionUtilities.runCommand("/usr/bin/killall", arguments: ["vpnagentd"])
            steps.append("Restarted vpnagentd")
        }

        let message = steps.isEmpty ? "AnyConnect fixes applied" : steps.joined(separator: ", ")
        HelperLogger.shared.info("[AnyConnectFix] Done: \(message)")
        completion(true, message)
    }

    private func clearSearchDomains() {
        let servicesOutput = DetectionUtilities.runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
        let services = servicesOutput.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("An") }

        for service in services {
            let trimmed = service.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                arguments: ["-setsearchdomains", trimmed, "Empty"])
        }
    }
}
