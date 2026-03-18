import Foundation
import SystemConfiguration

/// Detects VPN connection state by checking for active utun interfaces.
/// Swift reimplementation of the utun check from vpn-monitor.sh.
final class VPNDetector {
    /// Returns the current VPN state by checking network interfaces.
    func currentState() -> VPNState {
        let utunInterfaces = getActiveUtunInterfaces()
        if utunInterfaces.isEmpty {
            return .disconnected
        }
        return .connected
    }

    /// Returns a list of utun interfaces that have an IPv4 address assigned.
    func getActiveUtunInterfaces() -> [String] {
        var result: [String] = []

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return result
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)

            // Check for utun interfaces with IPv4 addresses
            if name.hasPrefix("utun") && ptr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                // Verify the interface is up
                let flags = Int32(ptr.pointee.ifa_flags)
                if flags & IFF_UP != 0 && flags & IFF_RUNNING != 0 {
                    if !result.contains(name) {
                        result.append(name)
                    }
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return result
    }
}
