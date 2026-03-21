import UserNotifications

/// Manages native macOS notifications via UNUserNotificationCenter.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, NotificationServiceProtocol {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let prefs = AppPreferences.shared

    private override init() {
        super.init()
        center.delegate = self
        AppLogger.shared.debug("NotificationService initialized")
    }

    func requestPermission() {
        AppLogger.shared.debug("Requesting notification permission...")
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLogger.shared.error("Notification permission error: \(error.localizedDescription)")
            }
            AppLogger.shared.info("Notification permission granted: \(granted)")
        }
    }

    func postVPNConnected() {
        guard prefs.notifyOnConnect else {
            AppLogger.shared.debug("Skipping VPN Connected notification (disabled in preferences)")
            return
        }
        AppLogger.shared.info("Notification sent: VPN Connected")
        post(
            title: "VPN Connected",
            body: "VPN tunnel is active.",
            identifier: "vpn-connected"
        )
    }

    func postVPNDisconnected() {
        guard prefs.notifyOnDisconnect else {
            AppLogger.shared.debug("Skipping VPN Disconnected notification (disabled in preferences)")
            return
        }
        AppLogger.shared.info("Notification sent: VPN Disconnected")
        post(
            title: "VPN Disconnected",
            body: "VPN tunnel was disconnected. Monitoring for issues...",
            identifier: "vpn-disconnected"
        )
    }

    func postFixApplied(message: String) {
        guard prefs.notifyOnFix else {
            AppLogger.shared.debug("Skipping VPN Fix Applied notification (disabled in preferences)")
            return
        }
        AppLogger.shared.info("Notification sent: VPN Fix Applied")
        post(
            title: "VPN Fix Applied",
            body: message.isEmpty ? "Network connectivity restored." : message,
            identifier: "vpn-fix-applied"
        )
    }

    // MARK: - Phase 3: Multi-VPN Notifications

    func postVPNIssuesDetected(client: String, issueCount: Int) {
        guard prefs.notifyOnFix else { return }
        AppLogger.shared.info("Notification sent: \(issueCount) issues detected for \(client)")
        post(
            title: "VPN Issues Detected",
            body: "\(client): \(issueCount) issue\(issueCount == 1 ? "" : "s") found that may affect your network.",
            identifier: "vpn-issues-\(client)"
        )
    }

    func postFixApplied(client: String, message: String) {
        guard prefs.notifyOnFix else { return }
        AppLogger.shared.info("Notification sent: Fix applied for \(client)")
        post(
            title: "Fix Applied — \(client)",
            body: message.isEmpty ? "Network issues resolved." : message,
            identifier: "vpn-fix-\(client)"
        )
    }

    func postFixAllCompleted(fixedCount: Int, failedCount: Int) {
        guard prefs.notifyOnFix else { return }
        let body: String
        if failedCount == 0 {
            body = "Successfully fixed \(fixedCount) VPN client\(fixedCount == 1 ? "" : "s")."
        } else {
            body = "Fixed \(fixedCount), failed \(failedCount) VPN client\(failedCount == 1 ? "" : "s")."
        }
        AppLogger.shared.info("Notification sent: Fix All completed (fixed=\(fixedCount), failed=\(failedCount))")
        post(
            title: "Fix All Completed",
            body: body,
            identifier: "vpn-fix-all"
        )
    }

    func postTestNotification() {
        AppLogger.shared.debug("Notification sent: Test")
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
                AppLogger.shared.error("Failed to post notification '\(identifier)': \(error.localizedDescription)")
            } else {
                AppLogger.shared.debug("Notification '\(identifier)' delivered to notification center")
            }
        }
    }
}
