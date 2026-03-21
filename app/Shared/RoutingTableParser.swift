import Foundation

/// Parses macOS routing tables to detect VPN presence.
/// Shared between the app (local pre-XPC detection) and helper (full detection).
enum RoutingTableParser {

    /// Checks if the routing table output indicates an active VPN connection.
    /// Looks for OpenVPN's signature routes: 0/1 and 128.0/1 via a utun interface.
    static func detectVPNFromNetstat(_ output: String) -> Bool {
        var has0slash1 = false
        var has128slash1 = false

        for line in output.components(separatedBy: .newlines) {
            if line.contains("utun") {
                if line.hasPrefix("0/1") || line.contains(" 0/1 ") {
                    has0slash1 = true
                }
                if line.hasPrefix("128.0/1") || line.contains(" 128.0/1 ") {
                    has128slash1 = true
                }
            }
        }

        return has0slash1 && has128slash1
    }
}
