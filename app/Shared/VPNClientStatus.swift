import Foundation

/// Detection result for a single VPN client.
struct VPNClientStatus: Codable, Sendable, Identifiable {
    var id: String { clientType.rawValue }

    let clientType: VPNClientType
    let installed: Bool
    let running: Bool
    let connectionState: VPNState
    let detectedIssues: [VPNIssue]
    let interfaceName: String?
    let processName: String?
    let appPath: String?

    var hasIssues: Bool { !detectedIssues.isEmpty }
    var issueCount: Int { detectedIssues.count }

    var highestSeverity: VPNIssue.Severity? {
        detectedIssues.map(\.severity).min()
    }
}
