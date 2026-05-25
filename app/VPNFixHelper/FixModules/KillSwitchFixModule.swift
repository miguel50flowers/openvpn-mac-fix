import Foundation

/// Clears VPN kill-switch pf rules for NordVPN, Proton VPN, Mullvad, PIA, Windscribe, etc.
///
/// SAFETY: this only flushes the VPN-specific pf *anchors*. It NEVER runs `pfctl -d` to disable
/// the packet filter globally (the previous version did, which can tear down unrelated firewall
/// rules and is exactly the kind of broad, unverified change that left users worse off).
final class KillSwitchFixModule: VPNFixModule {
    // This module handles multiple clients; clientType is for registration
    let clientType: VPNClientType = .nordVPN

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        let killSwitchIssues = issues.filter { $0.type == .killSwitchActive }
        guard !killSwitchIssues.isEmpty else {
            completion(true, "No kill switch issues")
            return
        }

        HelperLogger.shared.info("[KillSwitchFix] Flushing VPN pf anchors (never disables pf globally)")

        var steps: [String] = []
        let anchors = DetectionUtilities.getPfAnchors()
        let vpnPatterns = ["NordVPN", "ProtonVPN", "mullvad", "pia", "Windscribe",
                           "Surfshark", "GlobalProtect"]

        for anchor in anchors {
            for pattern in vpnPatterns where anchor.lowercased().contains(pattern.lowercased()) {
                if let anchorName = extractAnchorName(from: anchor) {
                    let r = DetectionUtilities.runCommandWithStatus("/sbin/pfctl", arguments: ["-a", anchorName, "-F", "all"], timeout: 8)
                    if r.succeeded {
                        steps.append("Flushed anchor \(anchorName)")
                        HelperLogger.shared.debug("[KillSwitchFix] Flushed: \(anchorName)")
                    }
                }
            }
        }

        // NOTE: deliberately NO `pfctl -d`. Disabling the global packet filter is destructive and
        // can remove non-VPN firewall rules; we only ever flush the VPN anchors above.

        let message = steps.isEmpty ? "No VPN kill-switch anchors found" : steps.joined(separator: ", ")
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
