import Foundation

/// A snapshot of observed network health.
///
/// Every measurable field is **optional**: `nil` means the helper could not measure it (e.g. a
/// system command timed out) and MUST NOT be treated as a negative result. This is the core
/// guard against the old bug where a timed-out reading silently became "everything is fine / no
/// issues". Only a value that was actually observed (`true`/`false`) drives a conclusion.
struct NetworkHealthSnapshot: Equatable {
    /// Whether a DNS lookup actually resolved. `nil` = not measured.
    var dnsResolves: Bool?
    /// Whether a default route via a physical interface exists. `nil` = not measured.
    var hasDefaultRoute: Bool?
    /// Whether the default gateway answered (ping). `nil` = not measured.
    var gatewayReachable: Bool?
    /// Whether a `utun`/`ppp` tunnel interface is up with routes but no tunnel process. `nil` = not measured.
    var orphanedTunnelInterface: Bool?
    /// Whether DNS still points at a VPN/private resolver while no tunnel runs. `nil` = not measured.
    var staleVPNDns: Bool?
    /// Whether a real VPN tunnel process is currently running.
    var tunnelProcessRunning: Bool

    init(dnsResolves: Bool? = nil,
         hasDefaultRoute: Bool? = nil,
         gatewayReachable: Bool? = nil,
         orphanedTunnelInterface: Bool? = nil,
         staleVPNDns: Bool? = nil,
         tunnelProcessRunning: Bool = false) {
        self.dnsResolves = dnsResolves
        self.hasDefaultRoute = hasDefaultRoute
        self.gatewayReachable = gatewayReachable
        self.orphanedTunnelInterface = orphanedTunnelInterface
        self.staleVPNDns = staleVPNDns
        self.tunnelProcessRunning = tunnelProcessRunning
    }
}

/// Pure mapping from an observed snapshot to the network-health issues to surface.
///
/// Emits an issue only from data that was actually measured. A `nil` (unknown/timed-out) field
/// produces neither a false "no issue" nor a false issue — it is simply ignored.
enum NetworkHealthClassifier {
    static func issues(from s: NetworkHealthSnapshot) -> [VPNIssue] {
        var issues: [VPNIssue] = []

        let noRoute = (s.hasDefaultRoute == false)
        let noDNS = (s.dnsResolves == false)

        if noRoute && noDNS {
            // Both broken at once → one clear, high-signal issue rather than two.
            issues.append(VPNIssue(
                type: .noConnectivity,
                severity: .critical,
                description: "No default route and DNS is not resolving — the machine is offline"))
        } else {
            if noRoute {
                issues.append(VPNIssue(
                    type: .noDefaultRoute,
                    severity: .critical,
                    description: "No default route via a physical interface — traffic cannot leave the machine"))
            }
            if noDNS {
                issues.append(VPNIssue(
                    type: .dnsFailure,
                    severity: .critical,
                    description: "DNS is not resolving — host names cannot be looked up"))
            }
        }

        if s.orphanedTunnelInterface == true && !s.tunnelProcessRunning {
            issues.append(VPNIssue(
                type: .orphanedInterface,
                severity: .high,
                description: "A VPN tunnel interface (utun/ppp) is still up with no VPN process running"))
        }

        if s.staleVPNDns == true && !s.tunnelProcessRunning {
            issues.append(VPNIssue(
                type: .dnsLeak,
                severity: .high,
                description: "DNS still points at a VPN resolver while no VPN is connected"))
        }

        return issues
    }
}
