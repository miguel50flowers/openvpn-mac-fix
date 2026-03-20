import Foundation

/// Executes the bundled shell scripts via Process.
final class ScriptRunner {
    private let queue = DispatchQueue(label: "com.vpnfix.scriptrunner")
    private let installedResourcesPath = "/Library/PrivilegedHelperTools/VPNFixResources"

    /// Runs the fix-vpn-disconnect.sh script.
    func runFixScript(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] runFixScript requested")
        queue.async {
            guard let scriptPath = self.findScript(named: "fix-vpn-disconnect.sh") else {
                completion(false, "Script not found")
                return
            }

            self.execute(script: scriptPath, completion: completion)
        }
    }

    /// Runs the vpn-monitor.sh script.
    func runMonitorScript(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] runMonitorScript requested")
        queue.async {
            guard let scriptPath = self.findScript(named: "vpn-monitor.sh") else {
                completion(false, "Script not found")
                return
            }

            self.execute(script: scriptPath, completion: completion)
        }
    }

    // MARK: - Private

    /// Locates a script: tries installed path first, then bundle-relative.
    private func findScript(named name: String) -> String? {
        // Try installed resources path first
        let installedPath = "\(installedResourcesPath)/\(name)"
        if FileManager.default.fileExists(atPath: installedPath) {
            HelperLogger.shared.debug("[VPNFixHelper] Script found at installed path: \(installedPath)")
            return installedPath
        }

        // Fallback: bundle-relative path
        let helperPath = ProcessInfo.processInfo.arguments[0]
        let contentsURL = URL(fileURLWithPath: helperPath)
            .deletingLastPathComponent() // MacOS/
            .deletingLastPathComponent() // Contents/
        let scriptURL = contentsURL.appendingPathComponent("Resources/\(name)")

        if FileManager.default.fileExists(atPath: scriptURL.path) {
            HelperLogger.shared.debug("[VPNFixHelper] Script found at bundle path: \(scriptURL.path)")
            return scriptURL.path
        }

        HelperLogger.shared.error("[VPNFixHelper] Script not found: \(name)")
        return nil
    }

    private func execute(script: String, completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.debug("[VPNFixHelper] Executing script: \(script)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script]

        // Pass environment variables
        var env = ProcessInfo.processInfo.environment
        let logLevel = UserDefaults.standard.string(forKey: "logLevel") ?? "INFO"
        env["VPN_MONITOR_LOG_LEVEL"] = logLevel
        HelperLogger.shared.debug("[VPNFixHelper] Script environment: VPN_MONITOR_LOG_LEVEL=\(logLevel)")
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()

            // Wait with a 45-second timeout instead of blocking forever
            let semaphore = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in
                semaphore.signal()
            }
            let result = semaphore.wait(timeout: .now() + 45)

            if result == .timedOut {
                HelperLogger.shared.error("[VPNFixHelper] Script timed out after 45 seconds, terminating")
                process.terminate()
                completion(false, "Script execution timed out after 45 seconds")
                return
            }

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errData, encoding: .utf8) ?? ""

            let success = process.terminationStatus == 0

            if success {
                let truncated = output.count > 200 ? String(output.prefix(200)) + "..." : output
                HelperLogger.shared.debug("[VPNFixHelper] Script completed (exit 0): \(truncated)")
            } else {
                HelperLogger.shared.error("[VPNFixHelper] Script failed (exit \(process.terminationStatus)): \(errorOutput)")
            }

            completion(success, success ? output : errorOutput)
        } catch {
            HelperLogger.shared.error("[VPNFixHelper] Failed to execute script: \(error.localizedDescription)")
            completion(false, error.localizedDescription)
        }
    }
}
