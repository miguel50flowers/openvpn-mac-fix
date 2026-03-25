import Foundation

/// Runs macOS built-in networkQuality tool and returns parsed results.
final class SpeedTestModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[SpeedTest] Running networkQuality test")

        let result = DetectionUtilities.runCommandWithStatus("/usr/bin/networkQuality", arguments: ["-s"], timeout: 30)
        guard result.succeeded else {
            HelperLogger.shared.error("[SpeedTest] networkQuality failed (exit \(result.exitCode))")
            completion(false, "Speed test failed — networkQuality not available or timed out")
            return
        }

        // Parse output for key metrics
        let output = result.output
        var download = "N/A"
        var upload = "N/A"
        var responsiveness = "N/A"

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Upload capacity:") || trimmed.contains("Uplink capacity:") {
                upload = extractValue(from: trimmed)
            } else if trimmed.contains("Download capacity:") || trimmed.contains("Downlink capacity:") {
                download = extractValue(from: trimmed)
            } else if trimmed.contains("Responsiveness:") || trimmed.contains("RPM") {
                responsiveness = trimmed
            }
        }

        let msg = "Download: \(download), Upload: \(upload), \(responsiveness)"
        HelperLogger.shared.info("[SpeedTest] \(msg)")
        completion(true, msg)
    }

    private func extractValue(from line: String) -> String {
        // Extract the numeric value and unit from lines like "Upload capacity: 45.123 Mbps"
        let parts = line.components(separatedBy: ":")
        return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : line
    }
}
