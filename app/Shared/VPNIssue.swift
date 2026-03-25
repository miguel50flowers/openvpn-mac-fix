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

        // Phase 4: Network health issues
        case mtuMismatch
        case selfAssignedIP
        case stuckInterface

        var fixDescription: String {
            switch self {
            case .staleRoutes: return "Remove leftover routes and flush DNS"
            case .killSwitchActive: return "Remove firewall (pf) rules blocking traffic"
            case .dnsLeak: return "Reset DNS configuration to defaults"
            case .orphanedInterface: return "Clean up orphaned network interface"
            case .staleProxy: return "Remove stale proxy settings"
            case .stalePfRules: return "Remove leftover packet filter rules"
            case .daemonPersistence: return "Background process running (informational)"
            case .mtuMismatch: return "Reset interface MTU to default 1500"
            case .selfAssignedIP: return "Renew DHCP lease to obtain valid IP"
            case .stuckInterface: return "Reset network interface (down/up cycle)"
            }
        }
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
