import Foundation
import Darwin

struct SystemInfo {
    let macOSVersion: String
    let hardwareModel: String
    let chipArchitecture: String
    let physicalMemoryGB: String
    let appVersion: String
    let buildNumber: String
    let activeInterfaces: [String]

    func formattedMarkdown() -> String {
        var lines: [String] = []
        lines.append("| Field | Value |")
        lines.append("|-------|-------|")
        lines.append("| macOS | \(macOSVersion) |")
        lines.append("| Model | \(hardwareModel) |")
        lines.append("| Chip | \(chipArchitecture) |")
        lines.append("| Memory | \(physicalMemoryGB) GB |")
        lines.append("| App Version | \(appVersion) (\(buildNumber)) |")
        lines.append("| Interfaces | \(activeInterfaces.joined(separator: ", ")) |")
        return lines.joined(separator: "\n")
    }
}

enum SystemInfoCollector {

    static func collect() -> SystemInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let macOS = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        let model = sysctlString("hw.model") ?? "Unknown"

        #if arch(arm64)
        let chip = "Apple Silicon (arm64)"
        #else
        let chip = "Intel (x86_64)"
        #endif

        let memBytes = ProcessInfo.processInfo.physicalMemory
        let memGB = String(format: "%.0f", Double(memBytes) / 1_073_741_824)

        let appVer = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

        let interfaces = activeNetworkInterfaces()

        return SystemInfo(
            macOSVersion: macOS,
            hardwareModel: model,
            chipArchitecture: chip,
            physicalMemoryGB: memGB,
            appVersion: appVer,
            buildNumber: build,
            activeInterfaces: interfaces
        )
    }

    // MARK: - Private

    private static func sysctlString(_ name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    private static func activeNetworkInterfaces() -> [String] {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return [] }
        defer { freeifaddrs(first) }

        var seen = Set<String>()
        var result: [String] = []

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let addr = current {
            let name = String(cString: addr.pointee.ifa_name)
            let flags = Int32(addr.pointee.ifa_flags)
            let family = addr.pointee.ifa_addr?.pointee.sa_family

            if family == UInt8(AF_INET),
               flags & IFF_UP != 0,
               name != "lo0",
               !seen.contains(name) {
                seen.insert(name)
                result.append(name)
            }
            current = addr.pointee.ifa_next
        }
        return result
    }
}
