// ContentView.swift
// Health Bee — Root View with 3-Tab Navigation

import SwiftUI

struct ContentView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab(theme.labels.sessionsTab, systemImage: "bubble.fill", value: 0) {
                SessionsListView()
            }
            Tab(theme.labels.homeTab, systemImage: "waveform", value: 1) {
                HomeView()
            }
            Tab(theme.labels.settingsTab, systemImage: "gearshape", value: 2) {
                SettingsView()
            }
        }
        .tint(theme.accent)
    }
}
