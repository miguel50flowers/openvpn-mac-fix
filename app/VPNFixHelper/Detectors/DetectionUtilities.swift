import Foundation

/// Shared helpers for VPN detection — runs system commands and parses output.
enum DetectionUtilities {

    // MARK: - Timeout-aware reads

    /// Longer budget for detection reads. Content-filter VPNs (e.g. FortiClient) can make
    /// scutil/pfctl/netstat slow; the old 5s budget produced constant false "empty" results that
    /// were then misread as "no VPN / no issues".
    static let detectionTimeout: TimeInterval = 12

    /// A parsed system read that also reports whether it actually succeeded. `available == false`
    /// means the command timed out or failed to launch — an empty value must NOT be trusted as a
    /// real negative. This is the core guard against silent-failure misclassification.
    struct Read<Value> {
        let value: Value
        let available: Bool
    }

    private static func runRead(_ path: String, _ arguments: [String], timeout: TimeInterval) -> (output: String, available: Bool) {
        let r = runCommandWithStatus(path, arguments: arguments, timeout: timeout)
        // Unavailable on timeout or launch failure (exit -1). Otherwise the output is real, even
        // if the command exited non-zero.
        let available = !r.timedOut && r.exitCode != -1
        return (available ? r.output : "", available)
    }

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
        runningProcessesReading().value
    }

    /// Timeout-aware process list. `available == false` ⇒ `ps` timed out; callers must not treat
    /// the empty set as "nothing is running".
    static func runningProcessesReading(timeout: TimeInterval = detectionTimeout) -> Read<Set<String>> {
        let (output, available) = runRead("/bin/ps", ["-axo", "comm"], timeout: timeout)
        var names = Set<String>()
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let baseName = (trimmed as NSString).lastPathComponent
            if !baseName.isEmpty { names.insert(baseName) }
        }
        return Read(value: names, available: available)
    }

    static func isAppInstalled(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Routing Table

    static func getRoutingTable() -> String {
        routingTableReading().value
    }

    /// Timeout-aware routing table. `available == false` ⇒ `netstat` timed out; an empty string
    /// then must NOT be classified as "no VPN / disconnected".
    static func routingTableReading(timeout: TimeInterval = detectionTimeout) -> Read<String> {
        let (output, available) = runRead("/usr/sbin/netstat", ["-rn"], timeout: timeout)
        return Read(value: output, available: available)
    }

    // MARK: - PF (Packet Filter)

    static func getPfAnchors() -> [String] {
        pfAnchorsReading().value
    }

    static func pfAnchorsReading(timeout: TimeInterval = detectionTimeout) -> Read<[String]> {
        let (output, available) = runRead("/sbin/pfctl", ["-sr"], timeout: timeout)
        return Read(value: output.components(separatedBy: .newlines).filter { !$0.isEmpty }, available: available)
    }

    // MARK: - DNS

    static func getDNSServers() -> [String] {
        dnsServersReading().value
    }

    static func dnsServersReading(timeout: TimeInterval = detectionTimeout) -> Read<[String]> {
        let (output, available) = runRead("/usr/sbin/scutil", ["--dns"], timeout: timeout)
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
        return Read(value: servers, available: available)
    }

    // MARK: - Proxy

    static func getProxySettings() -> [String: String] {
        proxySettingsReading().value
    }

    static func proxySettingsReading(timeout: TimeInterval = detectionTimeout) -> Read<[String: String]> {
        let (output, available) = runRead("/usr/sbin/scutil", ["--proxy"], timeout: timeout)
        var settings: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonRange = trimmed.range(of: " : ") {
                let key = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                settings[key] = value
            }
        }
        return Read(value: settings, available: available)
    }

    // MARK: - Interfaces

    static func getActiveInterfaces() -> [NetworkInterface] {
        activeInterfacesReading().value
    }

    static func activeInterfacesReading(timeout: TimeInterval = detectionTimeout) -> Read<[NetworkInterface]> {
        let (output, available) = runRead("/sbin/ifconfig", ["-a"], timeout: timeout)
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

        return Read(value: interfaces.filter { $0.isUp }, available: available)
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

    // MARK: - Multi-Process Helpers

    /// Returns true if any of the given process names are running.
    static func isAnyProcessRunning(_ names: [String], in processes: Set<String>) -> Bool {
        names.contains { processes.contains($0) }
    }

    /// Returns the first matching running process name, or nil.
    static func firstRunningProcess(_ names: [String], in processes: Set<String>) -> String? {
        names.first { processes.contains($0) }
    }

    /// Checks if any utun interface has an IPv4 address assigned (active VPN tunnel).
    static func hasUtunWithIPv4(in interfaces: [NetworkInterface]) -> Bool {
        interfaces.contains { $0.name.hasPrefix("utun") && $0.address != nil && $0.isUp }
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

    // MARK: - Connectivity probes (active network health)

    /// Whether DNS can actually resolve a name via macOS's native resolver path.
    /// Returns `nil` when it could not be determined (all probes timed out / failed to launch) —
    /// callers must treat `nil` as "unknown", never as "broken".
    static func dnsResolves(hosts: [String] = ["apple.com", "cloudflare.com", "one.one.one.one"],
                            timeout: TimeInterval = 4) -> Bool? {
        var measuredAny = false
        for host in hosts {
            let r = runCommandWithStatus("/usr/bin/dscacheutil", arguments: ["-q", "host", "-a", "name", host], timeout: timeout)
            if r.timedOut || r.exitCode == -1 { continue }
            measuredAny = true
            if r.output.contains("ip_address:") || r.output.contains("ipv6_address:") {
                return true
            }
        }
        return measuredAny ? false : nil
    }

    /// Whether a default route via a physical interface (en*/bridge*) exists in a routing table
    /// that was actually available.
    static func hasPhysicalDefaultRoute(in routingTable: String) -> Bool {
        for line in routingTable.components(separatedBy: .newlines) where line.hasPrefix("default") {
            guard let iface = line.split(separator: " ").map(String.init).last else { continue }
            if iface.hasPrefix("en") || iface.hasPrefix("bridge") { return true }
        }
        return false
    }

    /// Pings a host once with a short deadline. `nil` = couldn't run.
    static func pingReachable(_ host: String, timeout: TimeInterval = 4) -> Bool? {
        let r = runCommandWithStatus("/sbin/ping", arguments: ["-c", "1", "-t", "2", host], timeout: timeout)
        if r.timedOut || r.exitCode == -1 { return nil }
        return r.exitCode == 0
    }

    /// The interface backing the current default route (e.g. "en0"), or `nil` if undeterminable.
    static func defaultRouteInterface(timeout: TimeInterval = 6) -> String? {
        let r = runCommandWithStatus("/sbin/route", arguments: ["-n", "get", "default"], timeout: timeout)
        guard !r.timedOut, r.exitCode != -1 else { return nil }
        for line in r.output.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("interface:") {
                return t.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// The network *service* name (e.g. "Wi-Fi") backing a given device (e.g. "en0"), for safe
    /// service-level operations via `networksetup`. `nil` if undeterminable.
    static func serviceName(forInterface device: String, timeout: TimeInterval = 8) -> String? {
        let r = runCommandWithStatus("/usr/sbin/networksetup", arguments: ["-listnetworkserviceorder"], timeout: timeout)
        guard !r.timedOut, r.exitCode != -1 else { return nil }
        let lines = r.output.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() where line.contains("Device: \(device))") {
            guard i > 0 else { continue }
            // Previous line looks like: "(1) Wi-Fi" or "(2) Ethernet"
            let prev = lines[i - 1]
            if let sep = prev.range(of: ") ") {
                let name = String(prev[sep.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        return nil
    }

    /// The primary network service name (service backing the default route).
    static func primaryServiceName() -> String? {
        guard let device = defaultRouteInterface() else { return nil }
        return serviceName(forInterface: device)
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
