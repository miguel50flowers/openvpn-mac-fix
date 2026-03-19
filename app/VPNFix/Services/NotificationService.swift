import UserNotifications

/// Manages native macOS notifications via UNUserNotificationCenter.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let prefs = AppPreferences.shared

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("[VPNFix] Notification permission error: \(error.localizedDescription)")
            }
            NSLog("[VPNFix] Notification permission granted: \(granted)")
        }
    }

    func postVPNConnected() {
        guard prefs.notifyOnConnect else { return }
        post(
            title: "VPN Connected",
            body: "VPN tunnel is active.",
            identifier: "vpn-connected"
        )
    }

    func postVPNDisconnected() {
        guard prefs.notifyOnDisconnect else { return }
        post(
            title: "VPN Disconnected",
            body: "VPN tunnel was disconnected. Monitoring for issues...",
            identifier: "vpn-disconnected"
        )
    }

    func postFixApplied(message: String) {
        guard prefs.notifyOnFix else { return }
        post(
            title: "VPN Fix Applied",
            body: message.isEmpty ? "Network connectivity restored." : message,
            identifier: "vpn-fix-applied"
        )
    }

    func postTestNotification() {
        post(
            title: "VPN Fix - Test",
            body: "Notifications are working correctly!",
            identifier: "vpn-test-\(UUID().uuidString)"
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Private

    private func post(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        center.add(request) { error in
            if let error {
                NSLog("[VPNFix] Failed to post notification: \(error.localizedDescription)")
            }
        }
    }
}
