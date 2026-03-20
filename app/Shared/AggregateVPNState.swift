import Foundation

/// Aggregate state for the menu bar, summarizing all detected VPN clients.
enum AggregateVPNState: Codable, Sendable {
    case allClear
    case vpnActive(count: Int)
    case issuesDetected(count: Int)
    case fixing
    case unknown

    var label: String {
        switch self {
        case .allClear: return "All Clear"
        case .vpnActive(let count): return "\(count) VPN\(count == 1 ? "" : "s") Active"
        case .issuesDetected(let count): return "\(count) Issue\(count == 1 ? "" : "s") Detected"
        case .fixing: return "Fixing..."
        case .unknown: return "Scanning..."
        }
    }

    var sfSymbol: String {
        switch self {
        case .allClear: return "checkmark.shield"
        case .vpnActive: return "shield.lefthalf.filled"
        case .issuesDetected: return "exclamationmark.shield"
        case .fixing: return "arrow.triangle.2.circlepath"
        case .unknown: return "questionmark.diamond"
        }
    }
}
