import Foundation

/// Shared helpers for VPN detection — runs system commands and parses output.
enum DetectionUtilities {

    // MARK: - Process Checks

    static func isProcessRunning(_ name: String) -> Bool {
        let output = runCommand("/bin/ps", arguments: ["-axo", "comm"])
        return output.components(separatedBy: .newlines).contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let baseName = (trimmed as NSString).lastPathComponent
            return baseName == name || trimmed.hasSuffix("/\(name)")
        }
    }

    static func getRunningProcesses() -> Set<String> {
        let output = runCommand("/bin/ps", arguments: ["-axo", "comm"])
        var names = Set<String>()
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let baseName = (trimmed as NSString).lastPathComponent
            if !baseName.isEmpty { names.insert(baseName) }
        }
        return names
    }

    static func isAppInstalled(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Routing Table

    static func getRoutingTable() -> String {
        runCommand("/usr/sbin/netstat", arguments: ["-rn"])
    }

    // MARK: - PF (Packet Filter)

    static func getPfAnchors() -> [String] {
        let output = runCommand("/sbin/pfctl", arguments: ["-sr"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - DNS

    static func getDNSServers() -> [String] {
        let output = runCommand("/usr/sbin/scutil", arguments: ["--dns"])
        var servers: [String] = []
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("nameserver[") {
                // Format: "nameserver[0] : 8.8.8.8"
                if let colonIndex = trimmed.range(of: " : ") {
                    let server = String(trimmed[colonIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !servers.contains(server) {
                        servers.append(server)
                    }
                }
            }
        }
        return servers
    }

    // MARK: - Proxy

    static func getProxySettings() -> [String: String] {
        let output = runCommand("/usr/sbin/scutil", arguments: ["--proxy"])
        var settings: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonRange = trimmed.range(of: " : ") {
                let key = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                settings[key] = value
            }
        }
        return settings
    }

    // MARK: - Interfaces

    static func getActiveInterfaces() -> [NetworkInterface] {
        let output = runCommand("/sbin/ifconfig", arguments: ["-a"])
        var interfaces: [NetworkInterface] = []
        var currentName: String?
        var currentAddress: String?
        var currentUp = false

        for line in output.components(separatedBy: .newlines) {
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") && line.contains(": flags=") {
                // Save previous interface
                if let name = currentName {
                    interfaces.append(NetworkInterface(name: name, address: currentAddress, isUp: currentUp))
                }
                // Parse new interface header: "en0: flags=8863<UP,...>"
                currentName = line.components(separatedBy: ":").first
                currentAddress = nil
                currentUp = line.contains("<UP")
            } else if let trimmed = Optional(line.trimmingCharacters(in: .whitespaces)),
                      trimmed.hasPrefix("inet ") {
                // Parse IPv4 address: "inet 192.168.1.10 netmask ..."
                let parts = trimmed.components(separatedBy: " ")
                if parts.count >= 2 {
                    currentAddress = parts[1]
                }
            }
        }
        // Don't forget the last interface
        if let name = currentName {
            interfaces.append(NetworkInterface(name: name, address: currentAddress, isUp: currentUp))
        }

        return interfaces.filter { $0.isUp }
    }

    // MARK: - Default Gateway

    static func getDefaultGateway(from routingTable: String) -> String? {
        for line in routingTable.components(separatedBy: .newlines) {
            if line.hasPrefix("default") {
                let parts = line.split(separator: " ").map(String.init)
                if parts.count >= 2 {
                    return parts[1]
                }
            }
        }
        return nil
    }

    // MARK: - Route Helpers

    static func hasRoute(_ prefix: String, via interfacePattern: String, in routingTable: String) -> Bool {
        for line in routingTable.components(separatedBy: .newlines) {
            if (line.hasPrefix(prefix) || line.contains(" \(prefix) ")) && line.contains(interfacePattern) {
                return true
            }
        }
        return false
    }

    static func hasDefaultRouteVia(_ interfacePattern: String, in routingTable: String) -> Bool {
        hasRoute("default", via: interfacePattern, in: routingTable)
    }

    // MARK: - Shell Runner

    static func runCommand(_ path: String, arguments: [String], timeout: TimeInterval = 5) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            HelperLogger.shared.error("[DetectionUtilities] Failed to run \(path): \(error.localizedDescription)")
            return ""
        }

        // Read pipe data async to avoid buffer deadlock — if output exceeds the ~64KB
        // macOS pipe buffer, the process blocks on write and waitUntilExit() never returns.
        var outputData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global().async {
            outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            HelperLogger.shared.error("[DetectionUtilities] Command timed out after \(Int(timeout))s: \(path)")
            return ""
        }

        readGroup.wait()
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    /// Result of a command execution, including exit code for error propagation.
    struct CommandResult {
        let output: String
        let exitCode: Int32
        let timedOut: Bool

        var succeeded: Bool { exitCode == 0 && !timedOut }
    }

    /// Runs a command and returns a typed result with exit code, preventing silent failures.
    static func runCommandWithStatus(_ path: String, arguments: [String], timeout: TimeInterval = 5) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            HelperLogger.shared.error("[DetectionUtilities] Failed to run \(path): \(error.localizedDescription)")
            return CommandResult(output: "", exitCode: -1, timedOut: false)
        }

        var outputData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global().async {
            outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            HelperLogger.shared.error("[DetectionUtilities] Command timed out after \(Int(timeout))s: \(path)")
            return CommandResult(output: "", exitCode: -1, timedOut: true)
        }

        readGroup.wait()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return CommandResult(output: output, exitCode: process.terminationStatus, timedOut: false)
    }
}
