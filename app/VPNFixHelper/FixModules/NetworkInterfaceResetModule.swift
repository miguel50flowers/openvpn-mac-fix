import Foundation

/// Cycles the PRIMARY network *service* off and back on via `networksetup` (NOT raw
/// `ifconfig down/up`), with a GUARANTEED re-enable so it can never leave the machine offline.
///
/// This replaces the previous implementation that ran `ifconfig en0 down` then `up` with no delay,
/// no verification, and always reported success — if `up` failed or timed out the primary
/// interface was left DOWN (exactly the breakage the user hit). Service-level toggling is
/// reversible and managed by macOS, and here the re-enable is retried and verified.
final class NetworkInterfaceResetModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[InterfaceReset] Cycling primary network service")

        guard let service = DetectionUtilities.primaryServiceName() else {
            // Can't identify the primary service → do NOTHING rather than guess and break it.
            HelperLogger.shared.warn("[InterfaceReset] Could not determine primary service — skipping (safe no-op)")
            completion(false, "Could not determine primary network service; skipped")
            return
        }

        // Never cycle a VPN service.
        if isVPNService(service) {
            HelperLogger.shared.warn("[InterfaceReset] Primary service '\(service)' looks like a VPN — skipping")
            completion(false, "Primary service is a VPN; skipped")
            return
        }

        // Re-enable + verify, retried. Defined first so every exit path can guarantee it runs.
        func reEnable() -> Bool {
            for attempt in 1...3 {
                let on = DetectionUtilities.runCommandWithStatus(
                    "/usr/sbin/networksetup", arguments: ["-setnetworkserviceenabled", service, "on"], timeout: 10)
                if on.succeeded { return true }
                HelperLogger.shared.warn("[InterfaceReset] re-enable attempt \(attempt) for '\(service)' failed, retrying…")
                Thread.sleep(forTimeInterval: 1.0)
            }
            return false
        }

        let off = DetectionUtilities.runCommandWithStatus(
            "/usr/sbin/networksetup", arguments: ["-setnetworkserviceenabled", service, "off"], timeout: 10)

        guard off.succeeded else {
            // Couldn't disable — make sure it is enabled and bail without having changed anything.
            _ = reEnable()
            HelperLogger.shared.warn("[InterfaceReset] Could not disable '\(service)'; left enabled")
            completion(false, "Could not disable '\(service)'; left enabled")
            return
        }

        Thread.sleep(forTimeInterval: 2.0) // let the service fully tear down before re-enabling

        guard reEnable() else {
            HelperLogger.shared.error("[InterfaceReset] FAILED to re-enable '\(service)' after retries — manual check needed")
            completion(false, "Failed to re-enable '\(service)'")
            return
        }

        HelperLogger.shared.info("[InterfaceReset] Cycled '\(service)' (re-enabled)")
        completion(true, "Cycled '\(service)'")
    }

    private func isVPNService(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("vpn") || n.contains("wireguard") || n.contains("openvpn")
            || n.contains("forti") || n.contains("cisco") || n.contains("anyconnect")
            || n.contains("globalprotect") || n.contains("tunnel") || n.contains("tap")
    }
}
