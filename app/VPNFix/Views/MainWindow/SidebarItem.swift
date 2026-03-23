import Foundation

enum SidebarSection: String, CaseIterable {
    case monitor = "Monitor"
    case settings = "Settings"
}

enum SidebarItem: String, Hashable, Identifiable, CaseIterable {
    case dashboard
    case vpnClients
    case network
    case logs
    case general
    case notifications
    case advanced
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .vpnClients: return "VPN Clients"
        case .network: return "Network"
        case .logs: return "Logs"
        case .general: return "General"
        case .notifications: return "Notifications"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .vpnClients: return "shield.checkered"
        case .network: return "network"
        case .logs: return "doc.text.magnifyingglass"
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard, .vpnClients, .network, .logs:
            return .monitor
        case .general, .notifications, .advanced, .about:
            return .settings
        }
    }

    static func items(for section: SidebarSection) -> [SidebarItem] {
        allCases.filter { $0.section == section }
    }
}
