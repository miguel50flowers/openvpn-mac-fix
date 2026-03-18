import Foundation

/// Executes the bundled shell scripts via Process.
final class ScriptRunner {
    private let queue = DispatchQueue(label: "com.vpnfix.scriptrunner")

    /// Runs the fix-vpn-disconnect.sh script.
    func runFixScript(completion: @escaping (Bool, String) -> Void) {
        queue.async {
            guard let scriptPath = self.bundledScriptPath(named: "fix-vpn-disconnect.sh") else {
                completion(false, "Script not found in bundle")
                return
            }

            self.execute(script: scriptPath, completion: completion)
        }
    }

    /// Runs the vpn-monitor.sh script.
    func runMonitorScript(completion: @escaping (Bool, String) -> Void) {
        queue.async {
            guard let scriptPath = self.bundledScriptPath(named: "vpn-monitor.sh") else {
                completion(false, "Script not found in bundle")
                return
            }

            self.execute(script: scriptPath, completion: completion)
        }
    }

    // MARK: - Private

    /// Locates a script in the app bundle's Resources directory.
    /// The helper binary is at Contents/MacOS/VPNFixHelper, scripts at Contents/Resources/.
    private func bundledScriptPath(named name: String) -> String? {
        let helperPath = ProcessInfo.processInfo.arguments[0]
        let contentsURL = URL(fileURLWithPath: helperPath)
            .deletingLastPathComponent() // MacOS/
            .deletingLastPathComponent() // Contents/
        let scriptURL = contentsURL.appendingPathComponent("Resources/\(name)")

        if FileManager.default.fileExists(atPath: scriptURL.path) {
            return scriptURL.path
        }

        NSLog("[VPNFixHelper] Script not found at: \(scriptURL.path)")
        return nil
    }

    private func execute(script: String, completion: @escaping (Bool, String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script]

        // Pass environment variables
        var env = ProcessInfo.processInfo.environment
        env["VPN_MONITOR_LOG_LEVEL"] = UserDefaults.standard.string(forKey: "logLevel") ?? "INFO"
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errData, encoding: .utf8) ?? ""

            let success = process.terminationStatus == 0

            if !success {
                NSLog("[VPNFixHelper] Script failed (exit \(process.terminationStatus)): \(errorOutput)")
            }

            completion(success, success ? output : errorOutput)
        } catch {
            NSLog("[VPNFixHelper] Failed to execute script: \(error.localizedDescription)")
            completion(false, error.localizedDescription)
        }
    }
}
