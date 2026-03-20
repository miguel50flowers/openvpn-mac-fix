import Foundation

/// Snapshot of the current network state for diagnostics display.
struct NetworkDiagnostics: Codable, Sendable {
    let dnsServers: [String]
    let defaultGateway: String?
    let publicIP: String?
    let activeInterfaces: [NetworkInterface]
    let pfRulesActive: Bool
    let proxyConfigured: Bool
    let timestamp: Date
}

/// A detected network interface.
struct NetworkInterface: Codable, Sendable, Identifiable {
    var id: String { name }

    let name: String
    let address: String?
    let isUp: Bool
}
