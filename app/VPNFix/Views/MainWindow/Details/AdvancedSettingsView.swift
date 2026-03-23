import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Form {
            Picker("Log Level", selection: $prefs.logLevel) {
                Text("All").tag("ALL")
                Text("Debug").tag("DEBUG")
                Text("Info").tag("INFO")
                Text("Warning").tag("WARN")
                Text("Error").tag("ERROR")
            }
        }
        .formStyle(.grouped)
    }
}
