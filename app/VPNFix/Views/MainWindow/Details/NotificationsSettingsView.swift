import SwiftUI

struct NotificationsSettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Form {
            Toggle("Notify on VPN connect", isOn: $prefs.notifyOnConnect)
            Toggle("Notify on VPN disconnect", isOn: $prefs.notifyOnDisconnect)
            Toggle("Notify when fix is applied", isOn: $prefs.notifyOnFix)

            Divider()

            Button("Send Test Notification") {
                NotificationService.shared.postTestNotification()
            }
        }
        .formStyle(.grouped)
    }
}
