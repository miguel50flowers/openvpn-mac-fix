import SwiftUI

extension Notification.Name {
    static let scanIntervalChanged = Notification.Name("scanIntervalChanged")
}

/// User preferences stored via @AppStorage (UserDefaults).
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @AppStorage("monitoringEnabled") var monitoringEnabled: Bool = true
    @AppStorage("notifyOnConnect") var notifyOnConnect: Bool = true
    @AppStorage("notifyOnDisconnect") var notifyOnDisconnect: Bool = true
    @AppStorage("notifyOnFix") var notifyOnFix: Bool = true
    @AppStorage("logLevel") var logLevel: String = "ALL"
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasOfferedMigration") var hasOfferedMigration: Bool = false
    @AppStorage("updateCheckFrequency") var updateCheckFrequency: String = "automatic"
    @AppStorage("showDockIcon") var showDockIcon: Bool = false

    // Phase 3: Multi-VPN settings
    @AppStorage("scanInterval") var scanInterval: Int = 30
    @AppStorage("autoFixOnDetect") var autoFixOnDetect: Bool = false
    @AppStorage("showDashboardOnLaunch") var showDashboardOnLaunch: Bool = true

    // Dismissed issues (stored as JSON-encoded Set<String>)
    @AppStorage("dismissedIssues") var dismissedIssuesData: String = "[]"

    var dismissedIssues: Set<String> {
        get {
            guard let data = dismissedIssuesData.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(array)
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue)),
               let string = String(data: data, encoding: .utf8) {
                dismissedIssuesData = string
            }
        }
    }

    func dismissIssue(type: String, client: String) {
        var current = dismissedIssues
        current.insert("\(client):\(type)")
        dismissedIssues = current
    }

    func undismissAll() {
        dismissedIssues = []
    }

    func isIssueDismissed(type: String, client: String) -> Bool {
        dismissedIssues.contains("\(client):\(type)")
    }
}
