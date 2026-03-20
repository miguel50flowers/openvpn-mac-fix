import Foundation

/// Fixes kill switch pf rules for NordVPN, Proton VPN, Mullvad, PIA, Windscribe.
final class KillSwitchFixModule: VPNFixModule {
    // This module handles multiple clients; clientType is for registration
    let clientType: VPNClientType = .nordVPN

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        let killSwitchIssues = issues.filter { $0.type == .killSwitchActive }
        guard !killSwitchIssues.isEmpty else {
            completion(true, "No kill switch issues")
            return
        }

        HelperLogger.shared.info("[KillSwitchFix] Flushing VPN pf anchors")

        var steps: [String] = []

        // Flush all VPN-related pf anchors
        let anchors = DetectionUtilities.getPfAnchors()
        let vpnPatterns = ["NordVPN", "ProtonVPN", "mullvad", "pia", "Windscribe",
                           "Surfshark", "GlobalProtect"]

        for anchor in anchors {
            for pattern in vpnPatterns {
                if anchor.lowercased().contains(pattern.lowercased()) {
                    // Extract anchor name from rule
                    if let anchorName = extractAnchorName(from: anchor) {
                        _ = DetectionUtilities.runCommand("/sbin/pfctl", arguments: ["-a", anchorName, "-F", "all"])
                        steps.append("Flushed anchor \(anchorName)")
                        HelperLogger.shared.debug("[KillSwitchFix] Flushed: \(anchorName)")
                    }
                }
            }
        }

        // Check if only VPN rules remain; if so, disable pf entirely
        let remainingAnchors = DetectionUtilities.getPfAnchors()
        let hasNonVPN = remainingAnchors.contains { anchor in
            !vpnPatterns.contains { anchor.lowercased().contains($0.lowercased()) }
        }

        if !hasNonVPN && !remainingAnchors.isEmpty {
            _ = DetectionUtilities.runCommand("/sbin/pfctl", arguments: ["-d"])
            steps.append("Disabled pf (only VPN rules remained)")
            HelperLogger.shared.info("[KillSwitchFix] Disabled pf — no non-VPN rules remain")
        }

        let message = steps.isEmpty ? "Kill switch rules cleared" : steps.joined(separator: ", ")
        HelperLogger.shared.info("[KillSwitchFix] Done: \(message)")
        completion(true, message)
    }

    private func extractAnchorName(from rule: String) -> String? {
        // Rules look like: 'anchor "com.apple/250.NordVPN" all'
        if let start = rule.range(of: "\""), let end = rule.range(of: "\"", range: start.upperBound..<rule.endIndex) {
            return String(rule[start.upperBound..<end.lowerBound])
        }
        return nil
    }
}
