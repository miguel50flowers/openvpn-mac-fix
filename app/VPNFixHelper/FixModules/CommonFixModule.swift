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

        // Restore default route ONLY if it is actually missing — try every active physical
        // interface (not just the first), and VERIFY the route took before claiming success.
        let routeReading = DetectionUtilities.routingTableReading()
        if routeReading.available && !DetectionUtilities.hasPhysicalDefaultRoute(in: routeReading.value) {
            var restored = false
            for iface in candidateInterfaces() {
                let dhcpInfo = DetectionUtilities.runCommandWithStatus("/usr/sbin/ipconfig", arguments: ["getpacket", iface], timeout: 6)
                guard !dhcpInfo.timedOut, let gw = parseGateway(from: dhcpInfo.output) else { continue }
                let add = DetectionUtilities.runCommandWithStatus("/sbin/route", arguments: ["-n", "add", "default", gw], timeout: 6)
                let after = DetectionUtilities.routingTableReading()
                if add.succeeded && after.available && DetectionUtilities.hasPhysicalDefaultRoute(in: after.value) {
                    steps.append("Default route restored via \(gw) (\(iface))")
                    HelperLogger.shared.info("[CommonFix] Default route restored: \(gw) via \(iface)")
                    restored = true
                    break
                }
            }
            if !restored {
                failures.append("Could not restore default route")
            }
        } else if !routeReading.available {
            HelperLogger.shared.warn("[CommonFix] Routing table unavailable — skipping route restore (won't guess)")
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

    /// Active physical interfaces to try for default-route restoration (excludes loopback,
    /// tunnels and link-local helpers).
    private func candidateInterfaces() -> [String] {
        let excluded = ["lo", "utun", "awdl", "llw", "anpi", "bridge", "ap", "ipsec", "gif", "stf", "XHC", "ppp", "gpd"]
        return DetectionUtilities.getActiveInterfaces()
            .map { $0.name }
            .filter { name in !excluded.contains { name.hasPrefix($0) } }
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
