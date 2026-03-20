import Foundation

/// Fixes FortiClient — kills DNS forwarder on :53, restores DNS from 127.0.0.1.
final class FortiClientFixModule: VPNFixModule {
    let clientType: VPNClientType = .fortiClient

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[FortiClientFix] Fixing FortiClient issues")

        var steps: [String] = []

        // Fix DNS pointing to 127.0.0.1 (FortiClient local DNS forwarder)
        let dnsIssues = issues.filter { $0.type == .dnsLeak }
        if !dnsIssues.isEmpty {
            // Kill any FortiClient DNS forwarder
            _ = DetectionUtilities.runCommand("/usr/bin/killall", arguments: ["fct_launcher"])
            _ = DetectionUtilities.runCommand("/usr/bin/killall", arguments: ["FortiTray"])

            // Reset DNS to DHCP on all interfaces
            let servicesOutput = DetectionUtilities.runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
            for service in servicesOutput.components(separatedBy: .newlines) {
                let trimmed = service.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("An") else { continue }

                // Check if DNS is set to 127.0.0.1
                let dnsOutput = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                    arguments: ["-getdnsservers", trimmed])
                if dnsOutput.contains("127.0.0.1") {
                    // Reset to DHCP DNS (empty = use DHCP)
                    _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                        arguments: ["-setdnsservers", trimmed, "Empty"])
                    steps.append("Restored DNS on \(trimmed)")
                }
            }

            steps.append("Killed FortiClient DNS forwarder")
        }

        // Fix stale routes
        let routeIssues = issues.filter { $0.type == .staleRoutes }
        if !routeIssues.isEmpty {
            let routes = DetectionUtilities.getRoutingTable()
            // Remove ppp0 routes
            if routes.contains("ppp0") {
                _ = DetectionUtilities.runCommand("/sbin/ifconfig", arguments: ["ppp0", "destroy"])
                steps.append("Destroyed ppp0 interface")
            }
        }

        let message = steps.isEmpty ? "FortiClient fixes applied" : steps.joined(separator: ", ")
        HelperLogger.shared.info("[FortiClientFix] Done: \(message)")
        completion(true, message)
    }
}
