import Foundation

/// Toggles IPv6 off and back to automatic on all network services.
final class IPv6Module {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[IPv6] Resetting IPv6 on all services")
        let services = listNetworkServices()
        var steps: [String] = []

        for service in services {
            // Disable then re-enable to force clean state
            _ = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-setv6off", service])
            let enable = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-setv6automatic", service])
            if enable.succeeded {
                steps.append(service)
            }
        }

        let msg = steps.isEmpty ? "No services found" : "IPv6 reset on: \(steps.joined(separator: ", "))"
        HelperLogger.shared.info("[IPv6] Done: \(msg)")
        completion(true, msg)
    }

    private func listNetworkServices() -> [String] {
        let output = DetectionUtilities.runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
        return output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.contains("*") && !$0.contains("denotes") }
    }
}
