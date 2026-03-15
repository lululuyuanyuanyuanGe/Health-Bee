// SettingsView.swift
// Health Bee — Tab 2 (Settings)

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedLanguage: String = "English"
    @State private var selectedVoiceEngine: String = "Neural"
    @State private var selectedSTTEngine: String = "Whisper"
    @State private var selectedNoiseEngine: String = "RNNoise"
    @State private var selectedDiarizationEngine: String = "Pyannote"
    @State private var backendURL: String = "https://api.healthbee.app"
    @State private var apiKey: String = ""
    @State private var devModeEnabled: Bool = false

    private let languages = ["English", "Spanish", "French", "German", "Japanese", "Chinese"]
    private let voiceEngines = ["Neural", "Standard", "Enhanced"]
    private let sttEngines = ["Whisper", "DeepSpeech", "Apple STT"]
    private let noiseEngines = ["RNNoise", "DeepFilter", "None"]
    private let diarizationEngines = ["Pyannote", "SpeakerDiar", "None"]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                List {
                    // MARK: Setup — Voice Identity
                    Section("Setup") {
                        VoiceIdentityRow(enrollmentStatus: $appState.enrollmentStatus)
                    }

                    // MARK: Preferences
                    Section("Preferences") {
                        // Language
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(theme.iconSecondary)
                                .frame(width: 24)
                            Picker("Language", selection: $selectedLanguage) {
                                ForEach(languages, id: \.self) { lang in
                                    Text(lang).tag(lang)
                                }
                            }
                            .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                            .tint(theme.textSecondary)
                        }

                        // Appearance
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(theme.iconSecondary)
                                .frame(width: 24)
                            Picker("Appearance", selection: $themeManager.appearanceMode) {
                                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                            .tint(theme.textSecondary)
                        }
                    }

                    // MARK: Voice
                    Section("Voice") {
                        EnginePicker(
                            label: "TTS Engine",
                            options: voiceEngines,
                            selected: $selectedVoiceEngine
                        )
                    }

                    // MARK: Account
                    Section("Account") {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(theme.iconSecondary)
                            VStack(alignment: .leading) {
                                Text("User")
                                    .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                                    .foregroundColor(theme.textPrimary)
                                Text("user@example.com")
                                    .font(.system(size: 13, weight: .regular, design: theme.fontDesign))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Button {
                            // Sign out
                        } label: {
                            Text("Sign Out")
                                .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                                .foregroundColor(theme.destructive)
                        }
                    }

                    // MARK: Dev Mode toggle
                    Section {
                        Toggle("Developer Mode", isOn: $devModeEnabled)
                            .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                            .tint(theme.accent)
                    }

                    if devModeEnabled {
                        // MARK: Audio Pipeline (DEV)
                        Section("Audio Pipeline") {
                            EnginePicker(label: "STT Engine", options: sttEngines, selected: $selectedSTTEngine)
                            EnginePicker(label: "Noise Reduction", options: noiseEngines, selected: $selectedNoiseEngine)
                            EnginePicker(label: "Diarization", options: diarizationEngines, selected: $selectedDiarizationEngine)
                        }

                        // MARK: Backend (DEV)
                        Section("Backend") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Server URL")
                                    .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                                    .foregroundColor(theme.textSecondary)
                                TextField("https://...", text: $backendURL)
                                    .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                                    .foregroundColor(theme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(theme.surfaceSecondary)
                                    .cornerRadius(theme.radiusSM)
                            }
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("API Key")
                                    .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                                    .foregroundColor(theme.textSecondary)
                                SecureField("sk-...", text: $apiKey)
                                    .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                                    .foregroundColor(theme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(theme.surfaceSecondary)
                                    .cornerRadius(theme.radiusSM)
                            }
                        }

                        // MARK: Debug (DEV)
                        Section("Debug Views") {
                            NavigationLink("Orb Debug") {
                                OrbDebugView()
                            }
                            NavigationLink("Theme Debug") {
                                ThemeDebugView()
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(theme.background)
                .navigationTitle("Settings")
                .toolbarBackground(theme.background, for: .navigationBar)
                .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            }
        }
    }
}

// MARK: - Voice Identity Row

private struct VoiceIdentityRow: View {
    @Environment(\.theme) var theme
    @Binding var enrollmentStatus: EnrollmentStatus

    var iconName: String {
        switch enrollmentStatus {
        case .enrolled: return "checkmark.shield.fill"
        case .notEnrolled: return "person.crop.circle.badge.questionmark.fill"
        case .recording: return "mic.fill"
        }
    }

    var iconColor: Color {
        switch enrollmentStatus {
        case .enrolled: return theme.success
        case .notEnrolled: return theme.destructive
        case .recording: return theme.warning
        }
    }

    var statusText: String {
        switch enrollmentStatus {
        case .enrolled: return "Voice enrolled"
        case .notEnrolled: return "Not enrolled"
        case .recording: return "Recording enrollment..."
        }
    }

    var statusColor: Color {
        switch enrollmentStatus {
        case .enrolled: return theme.success
        case .notEnrolled: return theme.destructive
        case .recording: return theme.warning
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(enrollmentStatus == .enrolled ? theme.success.opacity(0.15) : theme.surfaceTertiary)
                    .frame(width: 44, height: 44)

                if enrollmentStatus == .recording {
                    ProgressView()
                        .tint(theme.warning)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Identity")
                    .font(.system(size: 16, weight: .semibold, design: theme.fontDesign))
                    .foregroundColor(theme.textPrimary)

                Text(statusText)
                    .font(.system(size: 13, weight: .regular, design: theme.fontDesign))
                    .foregroundColor(statusColor)
            }

            Spacer()

            Button {
                enrollmentStatus = .recording
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    enrollmentStatus = .enrolled
                }
            } label: {
                Text(enrollmentStatus == .enrolled ? "Retrain" : "Train")
                    .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Engine Picker

struct EnginePicker: View {
    @Environment(\.theme) var theme
    let label: String
    let options: [String]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            let gen = UISelectionFeedbackGenerator()
                            gen.selectionChanged()
                            selected = option
                        } label: {
                            Text(option)
                                .font(.system(size: 12, weight: theme.labelWeight, design: theme.fontDesign))
                                .foregroundColor(selected == option ? theme.textOnAccent : theme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selected == option ? theme.accent : theme.surface)
                                .cornerRadius(theme.radiusFull)
                                .overlay(
                                    Capsule()
                                        .stroke(theme.border.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Debug Views

private struct OrbDebugView: View {
    @Environment(\.theme) var theme
    @State private var mode: SessionMode = .duo

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack {
                OrbView(mode: mode, onTap: {})
                ModeSegmentedControl(selected: $mode)
            }
        }
        .navigationTitle("Orb Debug")
    }
}

private struct ThemeDebugView: View {
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    swatch(name: "background", color: theme.background)
                    swatch(name: "surface", color: theme.surface)
                    swatch(name: "surfaceSecondary", color: theme.surfaceSecondary)
                    swatch(name: "surfaceTertiary", color: theme.surfaceTertiary)
                    swatch(name: "accent", color: theme.accent)
                    swatch(name: "accentSecondary", color: theme.accentSecondary)
                    swatch(name: "destructive", color: theme.destructive)
                    swatch(name: "success", color: theme.success)
                    swatch(name: "warning", color: theme.warning)
                    swatch(name: "textPrimary", color: theme.textPrimary)
                    swatch(name: "textSecondary", color: theme.textSecondary)
                    swatch(name: "textTertiary", color: theme.textTertiary)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("Theme Debug")
    }

    @ViewBuilder
    private func swatch(name: String, color: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 40, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 0.5)
                )
            Text(name)
                .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
        }
    }
}

