import Foundation

/// Protocol for pluggable per-client VPN fix modules.
protocol VPNFixModule {
    var clientType: VPNClientType { get }
    func fix(issues: [VPNIssue], completion: @escaping (Bool, String) -> Void)
}
