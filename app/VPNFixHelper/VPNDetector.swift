import Foundation

/// Detects VPN connection state by checking for OpenVPN's characteristic routes.
/// OpenVPN pushes routes 0/1 and 128.0/1 via a utun interface to override the default route.
final class VPNDetector {
    /// Returns the current VPN state by checking the routing table.
    func currentState() -> VPNState {
        HelperLogger.shared.debug("[VPNFixHelper] VPN state detection requested")
        let result = isOpenVPNConnected() ? VPNState.connected : VPNState.disconnected
        HelperLogger.shared.debug("[VPNFixHelper] VPN state result: \(result.rawValue)")
        return result
    }

    /// Checks for OpenVPN's signature routes: 0/1 and 128.0/1 via utun.
    private func isOpenVPNConnected() -> Bool {
        let output = runNetstat()
        let lines = output.components(separatedBy: .newlines)

        var has0slash1 = false
        var has128slash1 = false

        for line in lines {
            if line.contains("utun") {
                if line.hasPrefix("0/1") || line.contains(" 0/1 ") {
                    has0slash1 = true
                }
                if line.hasPrefix("128.0/1") || line.contains(" 128.0/1 ") {
                    has128slash1 = true
                }
            }
        }

        HelperLogger.shared.debug("[VPNFixHelper] Route check: 0/1=\(has0slash1), 128.0/1=\(has128slash1)")
        return has0slash1 && has128slash1
    }

    private func runNetstat() -> String {
        HelperLogger.shared.debug("[VPNFixHelper] Running netstat -rn...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-rn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            HelperLogger.shared.error("[VPNFixHelper] Failed to run netstat: \(error.localizedDescription)")
            return ""
        }
    }
}
