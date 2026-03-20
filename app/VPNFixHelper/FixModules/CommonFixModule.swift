import Foundation

/// Common fixes applicable to all VPN clients: DNS flush, DHCP renew, default route restore.
final class CommonFixModule: VPNFixModule {
    let clientType: VPNClientType = .unknown

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[CommonFix] Running common network fixes")

        var steps: [String] = []

        // Flush DNS cache
        let dnsResult = DetectionUtilities.runCommand("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        _ = DetectionUtilities.runCommand("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        steps.append("DNS cache flushed")
        HelperLogger.shared.debug("[CommonFix] DNS flush done: \(dnsResult)")

        // Renew DHCP lease on primary interface
        let primaryInterface = findPrimaryInterface()
        if let iface = primaryInterface {
            _ = DetectionUtilities.runCommand("/usr/sbin/ipconfig", arguments: ["set", iface, "DHCP"])
            steps.append("DHCP renewed on \(iface)")
            HelperLogger.shared.debug("[CommonFix] DHCP renewed on \(iface)")
        }

        // Restore default route if missing
        let routes = DetectionUtilities.getRoutingTable()
        let gateway = DetectionUtilities.getDefaultGateway(from: routes)
        if gateway == nil, let iface = primaryInterface {
            // Try to get gateway from DHCP
            let dhcpInfo = DetectionUtilities.runCommand("/usr/sbin/ipconfig", arguments: ["getpacket", iface])
            if let gw = parseGateway(from: dhcpInfo) {
                _ = DetectionUtilities.runCommand("/sbin/route", arguments: ["-n", "add", "default", gw])
                steps.append("Default route restored via \(gw)")
                HelperLogger.shared.info("[CommonFix] Default route restored: \(gw)")
            }
        }

        let message = steps.joined(separator: ", ")
        HelperLogger.shared.info("[CommonFix] Done: \(message)")
        completion(true, message.isEmpty ? "Common fixes applied" : message)
    }

    private func findPrimaryInterface() -> String? {
        let output = DetectionUtilities.runCommand("/sbin/route", arguments: ["-n", "get", "default"])
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return "en0" // Fallback
    }

    private func parseGateway(from dhcpInfo: String) -> String? {
        for line in dhcpInfo.components(separatedBy: .newlines) {
            if line.contains("router") {
                // Format varies; look for IP pattern
                let parts = line.components(separatedBy: " ")
                return parts.last { $0.contains(".") && !$0.contains(":") }
            }
        }
        return nil
    }
}
