import Foundation

/// Restores IPv6 to **automatic** on physical network services.
///
/// This replaces the previous implementation that ran `-setv6off` on EVERY service (including VPN
/// services) and depended on a follow-up `-setv6automatic` to undo it — if that follow-up failed
/// or timed out, IPv6 was left permanently OFF, breaking connectivity. This version NEVER disables
/// IPv6 and never touches VPN services: setting `automatic` is idempotent and can only restore, not
/// break.
final class IPv6Module {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[IPv6] Restoring IPv6 to automatic on physical services")
        var restored: [String] = []
        var failed: [String] = []

        for service in listNetworkServices() where !isVPNService(service) {
            let r = DetectionUtilities.runCommandWithStatus(
                "/usr/sbin/networksetup", arguments: ["-setv6automatic", service], timeout: 10)
            if r.succeeded {
                restored.append(service)
            } else if !r.timedOut {
                // Some services legitimately reject the call; record but never treat as fatal.
                failed.append(service)
            }
        }

        let msg = restored.isEmpty
            ? "No physical services updated"
            : "IPv6 set automatic on: \(restored.joined(separator: ", "))"
        HelperLogger.shared.info("[IPv6] Done: \(msg)\(failed.isEmpty ? "" : " | skipped: \(failed.joined(separator: ", "))")")
        // Restoring-only is always safe, so report success even if some services were no-ops.
        completion(true, msg)
    }

    private func listNetworkServices() -> [String] {
        let r = DetectionUtilities.runCommandWithStatus(
            "/usr/sbin/networksetup", arguments: ["-listallnetworkservices"], timeout: 8)
        guard !r.timedOut, r.exitCode != -1 else { return [] }
        return r.output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.contains("*") && !$0.contains("denotes") }
    }

    private func isVPNService(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("vpn") || n.contains("wireguard") || n.contains("openvpn")
            || n.contains("forti") || n.contains("cisco") || n.contains("anyconnect")
            || n.contains("globalprotect") || n.contains("tunnel")
    }
}
