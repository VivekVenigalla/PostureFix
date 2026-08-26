import SwiftUI

@main
struct PostureFixApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .environmentObject(appState.camera)
        } label: {
            Image(systemName: appState.menuBarSymbolName)
                .task {
                    if !appState.hasCompletedOnboarding {
                        openWindow(id: "onboarding")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to PostureFix", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
                .environmentObject(appState.camera)
        }
        .windowResizability(.contentSize)

        Window("Weekly Posture", id: "stats") {
            StatsDashboardView()
                .environmentObject(appState)
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
