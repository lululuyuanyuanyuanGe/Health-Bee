// ContentView.swift
// Health Bee — Root View with 3-Tab Navigation

import SwiftUI

struct ContentView: View {
    @Environment(\.theme) var theme: AppTheme
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            SessionsListView()
                .tabItem {
                    Label(theme.labels.sessionsTab, systemImage: "bubble.fill")
                }
                .tag(0)

            HomeView()
                .tabItem {
                    Label(theme.labels.homeTab, systemImage: "waveform")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label(theme.labels.settingsTab, systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(theme.accent)
    }
}
