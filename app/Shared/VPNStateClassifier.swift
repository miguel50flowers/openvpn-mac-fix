import Foundation

/// Classifies the VPN connection state from `netstat -rn` output.
///
/// Pure (no I/O) so it can be unit-tested against captured routing tables. The live
/// command execution stays in the helper's `VPNDetector`, which feeds the raw output
/// here. Detects the routing patterns of OpenVPN (split `0/1` + `128.0/1` via `utun`),
/// WireGuard / IKEv2 (default route via `utun`), legacy PPP (`ppp0`), GlobalProtect
/// (`gpd0`) and IPsec interfaces.
enum VPNStateClassifier {
    static func classify(netstatOutput: String) -> VPNState {
        let lines = netstatOutput.components(separatedBy: .newlines)

        var has0slash1 = false
        var has128slash1 = false
        var hasDefaultUtun = false
        var hasPPP0 = false
        var hasGPD0 = false
        var hasIpsec = false

        for line in lines {
            if line.contains("utun") {
                if line.hasPrefix("0/1") || line.contains(" 0/1 ") { has0slash1 = true }
                if line.hasPrefix("128.0/1") || line.contains(" 128.0/1 ") { has128slash1 = true }
                if line.hasPrefix("default") { hasDefaultUtun = true }
            }
            if line.contains("ppp0") { hasPPP0 = true }
            if line.contains("gpd0") { hasGPD0 = true }
            if line.contains("ipsec") { hasIpsec = true }
        }

        let openVPNPattern = has0slash1 && has128slash1
        let anyVPN = openVPNPattern || hasDefaultUtun || hasPPP0 || hasGPD0 || hasIpsec

        return anyVPN ? .connected : .disconnected
    }
}
