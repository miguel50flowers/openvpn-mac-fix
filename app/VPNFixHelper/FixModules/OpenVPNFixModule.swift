import Foundation

/// Fixes OpenVPN, TunnelBear, PIA (OpenVPN mode) — removes 0/1 + 128.0/1 stale routes.
final class OpenVPNFixModule: VPNFixModule {
    let clientType: VPNClientType = .openVPN

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[OpenVPNFix] Removing OpenVPN-style routes")

        let routeIssues = issues.filter { $0.type == .staleRoutes }
        guard !routeIssues.isEmpty else {
            completion(true, "No stale routes to remove")
            return
        }

        // Remove the characteristic OpenVPN routes
        _ = DetectionUtilities.runCommand("/sbin/route", arguments: ["-n", "delete", "0/1"])
        _ = DetectionUtilities.runCommand("/sbin/route", arguments: ["-n", "delete", "128.0/1"])

        HelperLogger.shared.info("[OpenVPNFix] Removed 0/1 and 128.0/1 routes")
        completion(true, "Removed stale OpenVPN routes (0/1, 128.0/1)")
    }
}
