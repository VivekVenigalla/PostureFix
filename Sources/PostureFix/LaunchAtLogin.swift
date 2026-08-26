import ServiceManagement

///Note: SMAppService.mainApp registers a proper .app bundle with launchd.
///This project currently builds as an unbundled SwiftPM executable, so this
///will typically throw until it's packaged as a real .app (see roadmap Phase 11).
enum LaunchAtLogin {
    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("LaunchAtLogin: failed to update login item — \(error)")
        }
    }

    static var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil
    }
}
