import Foundation

/// Fixes Palo Alto GlobalProtect — kills PanGPS, destroys gpd0, clears search domains.
final class GlobalProtectFixModule: VPNFixModule {
    let clientType: VPNClientType = .globalProtect

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[GlobalProtectFix] Fixing GlobalProtect issues")

        var steps: [String] = []

        // Kill PanGPS process
        if DetectionUtilities.isProcessRunning("PanGPS") {
            _ = DetectionUtilities.runCommand("/usr/bin/killall", arguments: ["PanGPS"])
            steps.append("Killed PanGPS")
        }

        // Destroy gpd0 interface
        let interfaceIssues = issues.filter { $0.type == .orphanedInterface }
        if !interfaceIssues.isEmpty {
            _ = DetectionUtilities.runCommand("/sbin/ifconfig", arguments: ["gpd0", "destroy"])
            steps.append("Destroyed gpd0 interface")
        }

        // Clear search domains
        let dnsIssues = issues.filter { $0.type == .dnsLeak }
        if !dnsIssues.isEmpty {
            let servicesOutput = DetectionUtilities.runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
            for service in servicesOutput.components(separatedBy: .newlines) {
                let trimmed = service.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("An") else { continue }
                _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                    arguments: ["-setsearchdomains", trimmed, "Empty"])
            }
            steps.append("Cleared search domains")
        }

        // Handle kill switch pf rules
        let pfIssues = issues.filter { $0.type == .killSwitchActive }
        if !pfIssues.isEmpty {
            let anchors = DetectionUtilities.getPfAnchors()
            for anchor in anchors where anchor.contains("GlobalProtect") {
                if let name = extractAnchorName(from: anchor) {
                    _ = DetectionUtilities.runCommand("/sbin/pfctl", arguments: ["-a", name, "-F", "all"])
                    steps.append("Flushed pf anchor \(name)")
                }
            }
        }

        let message = steps.isEmpty ? "GlobalProtect fixes applied" : steps.joined(separator: ", ")
        HelperLogger.shared.info("[GlobalProtectFix] Done: \(message)")
        completion(true, message)
    }

    private func extractAnchorName(from rule: String) -> String? {
        if let start = rule.range(of: "\""), let end = rule.range(of: "\"", range: start.upperBound..<rule.endIndex) {
            return String(rule[start.upperBound..<end.lowerBound])
        }
        return nil
    }
}
