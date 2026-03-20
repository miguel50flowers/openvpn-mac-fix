import Foundation

/// Fixes WireGuard, NordLynx, Mullvad, PIA (WG mode), Surfshark (WG) — removes default via utun, destroys interface.
final class WireGuardFixModule: VPNFixModule {
    let clientType: VPNClientType = .wireGuard

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[WireGuardFix] Fixing WireGuard-style issues")

        var steps: [String] = []

        let routeIssues = issues.filter { $0.type == .staleRoutes }
        if !routeIssues.isEmpty {
            // Find and remove utun routes
            let routes = DetectionUtilities.getRoutingTable()
            for line in routes.components(separatedBy: .newlines) {
                if line.hasPrefix("default") && line.contains("utun") {
                    let parts = line.split(separator: " ").map(String.init)
                    if let gateway = parts.dropFirst().first {
                        _ = DetectionUtilities.runCommand("/sbin/route", arguments: ["-n", "delete", "default", gateway])
                        steps.append("Removed default route via \(gateway)")
                    }
                }
            }
        }

        let interfaceIssues = issues.filter { $0.type == .orphanedInterface }
        if !interfaceIssues.isEmpty {
            // Destroy orphaned utun interfaces
            let interfaces = DetectionUtilities.getActiveInterfaces()
            for iface in interfaces where iface.name.hasPrefix("utun") {
                _ = DetectionUtilities.runCommand("/sbin/ifconfig", arguments: [iface.name, "destroy"])
                steps.append("Destroyed \(iface.name)")
            }
        }

        let message = steps.isEmpty ? "WireGuard routes cleaned" : steps.joined(separator: ", ")
        HelperLogger.shared.info("[WireGuardFix] Done: \(message)")
        completion(true, message)
    }
}
