import Foundation

/// Detects and resets MTU on physical interfaces to the standard 1500.
final class MTUFixModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[MTU] Checking and fixing MTU on physical interfaces")
        var steps: [String] = []

        for iface in ["en0", "en1"] {
            let output = DetectionUtilities.runCommand("/sbin/ifconfig", arguments: [iface])
            guard let mtu = parseMTU(from: output), mtu != 1500 else { continue }

            let result = DetectionUtilities.runCommandWithStatus("/sbin/ifconfig", arguments: [iface, "mtu", "1500"])
            if result.succeeded {
                steps.append("\(iface): \(mtu) -> 1500")
                HelperLogger.shared.info("[MTU] Fixed \(iface) MTU from \(mtu) to 1500")
            }
        }

        let msg = steps.isEmpty ? "All interfaces at standard MTU" : steps.joined(separator: ", ")
        completion(true, msg)
    }

    private func parseMTU(from ifconfigOutput: String) -> Int? {
        for line in ifconfigOutput.components(separatedBy: .newlines) {
            if line.contains("mtu") {
                let parts = line.components(separatedBy: " ")
                if let idx = parts.firstIndex(of: "mtu"), idx + 1 < parts.count {
                    return Int(parts[idx + 1])
                }
            }
        }
        return nil
    }
}
