import Foundation

/// Fixes stale proxy settings for Surfshark, PIA, Zscaler.
final class ProxyFixModule: VPNFixModule {
    let clientType: VPNClientType = .zscaler

    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void) {
        let proxyIssues = issues.filter { $0.type == .staleProxy }
        guard !proxyIssues.isEmpty else {
            completion(true, "No proxy issues")
            return
        }

        HelperLogger.shared.info("[ProxyFix] Clearing stale proxy settings")

        var steps: [String] = []

        // Get all network services
        let servicesOutput = DetectionUtilities.runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
        let services = servicesOutput.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.contains("asterisk") && !$0.hasPrefix("An") }

        for service in services {
            let trimmed = service.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Disable HTTP proxy
            _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                arguments: ["-setwebproxystate", trimmed, "off"])

            // Disable HTTPS proxy
            _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                arguments: ["-setsecurewebproxystate", trimmed, "off"])

            // Disable SOCKS proxy
            _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                arguments: ["-setsocksfirewallproxystate", trimmed, "off"])

            // Disable auto proxy (PAC)
            _ = DetectionUtilities.runCommand("/usr/sbin/networksetup",
                arguments: ["-setautoproxystate", trimmed, "off"])

            steps.append(trimmed)
        }

        let message = "Cleared proxy on: \(steps.joined(separator: ", "))"
        HelperLogger.shared.info("[ProxyFix] Done: \(message)")
        completion(true, message)
    }
}
