// HealthBeeApp.swift
// Health Bee — App Entry Point

import SwiftUI

@main
struct HealthBeeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .applyTheme()
        }
    }
}
