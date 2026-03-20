import SwiftUI

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
    @AppStorage("showDashboardOnLaunch") var showDashboardOnLaunch: Bool = false
}
