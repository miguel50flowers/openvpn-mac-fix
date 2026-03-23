import Foundation

/// Parses macOS routing tables to detect VPN presence.
/// Shared between the app (local pre-XPC detection) and helper (full detection).
enum RoutingTableParser {

    /// Checks if the routing table output indicates an active VPN connection.
    /// Detects all VPN routing patterns: OpenVPN (0/1+128.0/1), WireGuard (default via utun),
    /// FortiClient (ppp0), GlobalProtect (gpd0), and IKEv2/IPSec (ipsec).
    static func detectVPNFromNetstat(_ output: String) -> Bool {
        var has0slash1 = false
        var has128slash1 = false
        var hasDefaultUtun = false
        var hasPPP0 = false
        var hasGPD0 = false
        var hasIpsec = false

        for line in output.components(separatedBy: .newlines) {
            if line.contains("utun") {
                if line.hasPrefix("0/1") || line.contains(" 0/1 ") {
                    has0slash1 = true
                }
                if line.hasPrefix("128.0/1") || line.contains(" 128.0/1 ") {
                    has128slash1 = true
                }
                if line.hasPrefix("default") {
                    hasDefaultUtun = true
                }
            }
            if line.contains("ppp0") { hasPPP0 = true }
            if line.contains("gpd0") { hasGPD0 = true }
            if line.contains("ipsec") { hasIpsec = true }
        }

        let openVPNPattern = has0slash1 && has128slash1
        return openVPNPattern || hasDefaultUtun || hasPPP0 || hasGPD0 || hasIpsec
    }
}
