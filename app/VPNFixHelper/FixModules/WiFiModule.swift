import Foundation

/// Wi-Fi specific repairs: toggle power cycle.
final class WiFiModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[WiFi] Cycling Wi-Fi power")

        let wifiDevice = findWiFiDevice()
        guard let device = wifiDevice else {
            completion(true, "No Wi-Fi interface found")
            return
        }

        let off = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-setairportpower", device, "off"])
        guard off.succeeded else {
            completion(false, "Failed to disable Wi-Fi")
            return
        }

        // Brief pause to let the interface fully deactivate
        Thread.sleep(forTimeInterval: 1.0)

        let on = DetectionUtilities.runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-setairportpower", device, "on"])
        if on.succeeded {
            HelperLogger.shared.info("[WiFi] Wi-Fi cycled on \(device)")
            completion(true, "Wi-Fi reset on \(device)")
        } else {
            completion(false, "Wi-Fi disabled but failed to re-enable")
        }
    }

    private func findWiFiDevice() -> String? {
        let output = DetectionUtilities.runCommand("/usr/sbin/networksetup", arguments: ["-listallhardwareports"])
        let lines = output.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() {
            if line.contains("Wi-Fi") || line.contains("AirPort") {
                if i + 1 < lines.count, lines[i + 1].contains("Device:") {
                    return lines[i + 1].replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return "en0" // Fallback
    }
}
