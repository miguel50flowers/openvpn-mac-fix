import Foundation

/// A user-defined VPN client entry for VPNs not in the built-in detector list.
struct CustomVPNEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String
    var appPath: String
    var processName: String
    var interfaceType: InterfaceType
    var dateAdded: Date

    enum InterfaceType: String, Codable, CaseIterable, Sendable {
        case utun
        case ppp
        case tun
        case ipsec
    }

    init(id: UUID = UUID(), displayName: String, appPath: String, processName: String, interfaceType: InterfaceType, dateAdded: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.appPath = appPath
        self.processName = processName
        self.interfaceType = interfaceType
        self.dateAdded = dateAdded
    }
}
