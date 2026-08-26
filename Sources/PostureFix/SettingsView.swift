import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Detection") {
                VStack(alignment: .leading) {
                    Text("Sensitivity")
                    Slider(value: $appState.settings.sensitivity, in: 0...1)
                    Text(appState.settings.sensitivity < 0.34 ? "Lenient" : appState.settings.sensitivity < 0.67 ? "Balanced" : "Strict")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Alerts") {
                VStack(alignment: .leading) {
                    Text("Minimum time between alerts: \(Int(appState.settings.alertCooldownMinutes)) min")
                    Slider(value: $appState.settings.alertCooldownMinutes, in: 1...30, step: 1)
                }
            }

            Section("Startup") {
                Toggle("Launch PostureFix at login", isOn: $appState.settings.launchAtLogin)
                if !LaunchAtLogin.isSupported {
                    Text("Not available in this debug build — requires a packaged .app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 380, minHeight: 320)
        .padding()
    }
}
