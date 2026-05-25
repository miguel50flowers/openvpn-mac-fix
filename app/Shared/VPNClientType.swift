import Foundation

/// Represents a known VPN client that can be detected and fixed.
enum VPNClientType: String, Codable, Sendable, CaseIterable {
    // Consumer
    case openVPN
    case wireGuard
    case nordVPN
    case expressVPN
    case surfshark
    case cyberGhost
    case protonVPN
    case mullvad
    case pia
    case ipVanish
    case windscribe
    case tunnelBear

    // Enterprise
    case ciscoAnyConnect
    case globalProtect
    case pulseSecure
    case zscaler
    case fortiClient

    // User-defined
    case custom

    // Generic
    case unknown

    /// Synthetic: not a VPN client, but the machine's overall network health surfaced as an entry
    /// so broken connectivity (no default route / DNS failure / orphaned tunnel) shows up in the
    /// same list and issue count as the VPN clients — this is the detection gap users hit where the
    /// VPN read "disconnected, no issues" while the internet was actually broken.
    case network

    enum Category: String, Codable, Sendable {
        case consumer
        case enterprise
    }

    var displayName: String {
        switch self {
        case .openVPN: return "OpenVPN"
        case .wireGuard: return "WireGuard"
        case .nordVPN: return "NordVPN"
        case .expressVPN: return "ExpressVPN"
        case .surfshark: return "Surfshark"
        case .cyberGhost: return "CyberGhost"
        case .protonVPN: return "Proton VPN"
        case .mullvad: return "Mullvad VPN"
        case .pia: return "Private Internet Access"
        case .ipVanish: return "IPVanish"
        case .windscribe: return "Windscribe"
        case .tunnelBear: return "TunnelBear"
        case .ciscoAnyConnect: return "Cisco AnyConnect"
        case .globalProtect: return "GlobalProtect"
        case .pulseSecure: return "Pulse Secure"
        case .zscaler: return "Zscaler"
        case .fortiClient: return "FortiClient"
        case .custom: return "Custom VPN"
        case .unknown: return "Unknown VPN"
        case .network: return "Network"
        }
    }

    var sfSymbol: String {
        if self == .custom { return "puzzlepiece.extension" }
        if self == .network { return "network" }
        switch category {
        case .consumer: return "shield.checkered"
        case .enterprise: return "building.2.crop.circle"
        }
    }

    var category: Category {
        switch self {
        case .openVPN, .wireGuard, .nordVPN, .expressVPN, .surfshark,
             .cyberGhost, .protonVPN, .mullvad, .pia, .ipVanish,
             .windscribe, .tunnelBear, .custom, .unknown, .network:
            return .consumer
        case .ciscoAnyConnect, .globalProtect, .pulseSecure, .zscaler, .fortiClient:
            return .enterprise
        }
    }
}
