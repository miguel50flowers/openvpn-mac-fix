import Foundation

/// Resets stuck network interfaces by cycling them down and up.
final class NetworkInterfaceResetModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[InterfaceReset] Resetting network interfaces")
        var steps: [String] = []

        for iface in ["en0", "en1"] {
            let check = DetectionUtilities.runCommand("/sbin/ifconfig", arguments: [iface])
            guard check.contains("status: active") || check.contains("<UP") else { continue }

            let down = DetectionUtilities.runCommandWithStatus("/sbin/ifconfig", arguments: [iface, "down"])
            let up = DetectionUtilities.runCommandWithStatus("/sbin/ifconfig", arguments: [iface, "up"])
            if down.succeeded && up.succeeded {
                steps.append("\(iface) reset")
            }
        }

        let msg = steps.isEmpty ? "No interfaces needed reset" : steps.joined(separator: ", ")
        HelperLogger.shared.info("[InterfaceReset] Done: \(msg)")
        completion(true, msg)
    }
}
