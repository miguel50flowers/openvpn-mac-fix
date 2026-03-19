import Foundation

/// Represents the current VPN connection state.
enum VPNState: String, Codable, Sendable {
    case connected
    case disconnected
    case fixing
    case unknown

    var label: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .fixing: return "Fixing..."
        case .unknown: return "Unknown"
        }
    }

    var sfSymbol: String {
        switch self {
        case .connected: return "shield.lefthalf.filled"
        case .disconnected: return "shield.slash"
        case .fixing: return "arrow.triangle.2.circlepath"
        case .unknown: return "questionmark.diamond"
        }
    }
}
