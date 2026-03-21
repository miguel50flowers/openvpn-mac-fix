import Foundation

/// Common fixes applicable to all VPN clients: DNS flush, DHCP renew, default route restore.
final class CommonFixModule: VPNFixModule {
    let clientType: VPNClientType = .unknown

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[CommonFix] Running common network fixes")

        var steps: [String] = []
        var failures: [String] = []

        // Flush DNS cache
        let dnsFlush = DetectionUtilities.runCommandWithStatus("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        let mDNS = DetectionUtilities.runCommandWithStatus("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        if dnsFlush.succeeded {
            steps.append("DNS cache flushed")
        } else {
            failures.append("DNS flush failed (exit \(dnsFlush.exitCode))")
        }
        if !mDNS.succeeded {
            HelperLogger.shared.warn("[CommonFix] mDNSResponder HUP failed (exit \(mDNS.exitCode))")
        }

        // Renew DHCP lease on primary interface
        let primaryInterface = findPrimaryInterface()
        if let iface = primaryInterface {
            let dhcp = DetectionUtilities.runCommandWithStatus("/usr/sbin/ipconfig", arguments: ["set", iface, "DHCP"])
            if dhcp.succeeded {
                steps.append("DHCP renewed on \(iface)")
            } else {
                failures.append("DHCP renew failed on \(iface) (exit \(dhcp.exitCode))")
            }
        }

        // Restore default route if missing
        let routes = DetectionUtilities.getRoutingTable()
        let gateway = DetectionUtilities.getDefaultGateway(from: routes)
        if gateway == nil, let iface = primaryInterface {
            let dhcpInfo = DetectionUtilities.runCommand("/usr/sbin/ipconfig", arguments: ["getpacket", iface])
            if let gw = parseGateway(from: dhcpInfo) {
                let routeResult = DetectionUtilities.runCommandWithStatus("/sbin/route", arguments: ["-n", "add", "default", gw])
                if routeResult.succeeded {
                    steps.append("Default route restored via \(gw)")
                    HelperLogger.shared.info("[CommonFix] Default route restored: \(gw)")
                } else {
                    failures.append("Route restore failed (exit \(routeResult.exitCode))")
                }
            }
        }

        let allSuccess = failures.isEmpty
        let message = steps.joined(separator: ", ")
        let failureMsg = failures.isEmpty ? "" : " | Failures: \(failures.joined(separator: ", "))"
        HelperLogger.shared.info("[CommonFix] Done: \(message)\(failureMsg)")
        completion(allSuccess, (message.isEmpty ? "Common fixes applied" : message) + failureMsg)
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
