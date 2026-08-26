import Foundation

struct AppSettings: Codable, Equatable {
    ///0 = least sensitive (fewer alerts), 1 = most sensitive (more alerts).
    var sensitivity: Double = 0.5
    var alertCooldownMinutes: Double = 1
    var launchAtLogin: Bool = false
}

enum SettingsStore {
    private static let key = "com.posturefix.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
