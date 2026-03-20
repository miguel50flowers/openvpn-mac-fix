import Foundation

/// An issue detected with a VPN client's network configuration.
struct VPNIssue: Codable, Sendable, Identifiable {
    let id: String
    let type: IssueType
    let severity: Severity
    let description: String

    init(type: IssueType, severity: Severity, description: String) {
        self.id = "\(type.rawValue)-\(UUID().uuidString.prefix(8))"
        self.type = type
        self.severity = severity
        self.description = description
    }

    enum IssueType: String, Codable, Sendable {
        case staleRoutes
        case stalePfRules
        case dnsLeak
        case orphanedInterface
        case staleProxy
        case killSwitchActive
        case daemonPersistence
    }

    enum Severity: String, Codable, Sendable, Comparable {
        case critical
        case high
        case medium
        case low

        private var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}
