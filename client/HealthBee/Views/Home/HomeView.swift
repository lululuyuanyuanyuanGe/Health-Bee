// HomeView.swift
// Health Bee — Tab 1 (Main Hub)

import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Mode Segmented Control
                    ModeSegmentedControl(selected: $appState.currentMode)
                        .padding(.top, Spacing.xl)

                    // Orb
                    VStack(spacing: Spacing.sm) {
                        OrbView(mode: appState.currentMode) {
                            appState.showActiveSession = true
                        }

                        Text(appState.currentMode == .duo
                            ? theme.labels.deployDuo
                            : theme.labels.deploySolo)
                            .font(.system(size: 16, weight: theme.bodyWeight, design: theme.fontDesign))
                            .foregroundColor(theme.textSecondary)
                    }

                    // Persona Carousel
                    PersonaCarouselSection()

                    // Dashboard Feed
                    DashboardFeedSection()

                    Spacer(minLength: Spacing.xxl)
                }
            }
        }
        .fullScreenCover(isPresented: $appState.showActiveSession) {
            ActiveSessionView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Persona Carousel Section

private struct PersonaCarouselSection: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var appState: AppState
    @State private var showPromptSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(theme.labels.personaLabel)
                .font(.system(size: 10, weight: theme.labelWeight, design: theme.fontDesign))
                .foregroundColor(theme.textTertiary)
                .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(appState.personas) { persona in
                        PersonaChip(
                            name: persona.name,
                            isSelected: appState.selectedPersonaID == persona.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appState.selectedPersonaID = persona.id
                                }
                                let gen = UISelectionFeedbackGenerator()
                                gen.selectionChanged()
                            },
                            onEdit: nil,
                            onDelete: {
                                appState.personas.removeAll { $0.id == persona.id }
                            }
                        )
                    }

                    // Add button
                    Button {
                        showPromptSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: theme.labelWeight))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.surfaceSecondary)
                            .cornerRadius(theme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadius)
                                    .stroke(theme.border, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .sheet(isPresented: $showPromptSheet) {
            PromptsListView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Dashboard Feed Section

private struct DashboardFeedSection: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(theme.labels.intelLabel)
                    .font(.system(size: 10, weight: theme.labelWeight, design: theme.fontDesign))
                    .foregroundColor(theme.textTertiary)

                Spacer()

                Button {
                    // Navigate to sessions
                    appState.selectedTab = 0
                } label: {
                    HStack(spacing: 2) {
                        Text("Session")
                            .font(.system(size: 12, weight: theme.labelWeight, design: theme.fontDesign))
                            .foregroundColor(theme.accentSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(theme.accentSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)

            if appState.dashboardCards.isEmpty {
                Text(theme.labels.noIntelText)
                    .font(.system(size: 14, weight: theme.bodyWeight, design: theme.fontDesign))
                    .foregroundColor(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.dashboardCards.enumerated()), id: \.element.id) { index, card in
                        DashboardCardRow(card: card)

                        if index < appState.dashboardCards.count - 1 {
                            Rectangle()
                                .fill(theme.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 38)
                        }
                    }
                }
                .background(theme.surface)
                .cornerRadius(theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(theme.border, lineWidth: 0.5)
                )
                .frame(maxHeight: 300)
                .padding(.horizontal, Spacing.lg)
            }
        }
    }
}
