// ActiveSessionView.swift
// Health Bee — Full-Screen Recording

import SwiftUI
import UIKit
import AudioToolbox

struct ActiveSessionView: View {
    @Environment(\.theme) var theme: AppTheme
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var flashOpacity: Double = 0
    @State private var textInput: String = ""
    @State private var userIsScrolling: Bool = false
    @State private var showBackToLive: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var statusText: String {
        switch appState.sessionState {
        case .recording: return theme.labels.listeningStatus
        case .processing: return theme.labels.processingStatus
        case .speaking: return theme.labels.speakingStatus
        }
    }

    var statusDotColor: Color {
        switch appState.sessionState {
        case .recording: return theme.accent
        case .processing: return theme.accentSecondary
        case .speaking: return theme.textPrimary
        }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            // Radar background
            ActiveSessionRadarVisualizer(sessionState: appState.sessionState)
                .offset(y: -100)
                .allowsHitTesting(false)

            // Flash overlay
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top HUD
                TopHUD(
                    statusText: statusText,
                    statusDotColor: statusDotColor,
                    personaName: appState.selectedPersona?.name ?? "Assistant"
                )
                .padding(.top, 32)

                Spacer()

                // Transcript area
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            let recent = Array(appState.activeSessionMessages.suffix(5))
                            ForEach(recent) { msg in
                                TurnBlock(message: msg)
                            }

                            // Live transcript turn
                            if !appState.liveTranscript.isEmpty || appState.sessionState == .recording {
                                LiveTurnBlock(
                                    transcript: appState.liveTranscript,
                                    sessionState: appState.sessionState
                                )
                            }

                            // Bottom anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom-anchor")
                                .onAppear { showBackToLive = false }
                                .onDisappear { showBackToLive = true }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: appState.activeSessionMessages.count) { _, _ in
                        if !userIsScrolling {
                            withAnimation { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
                        }
                    }
                    .onChange(of: appState.liveTranscript) { _, _ in
                        if !userIsScrolling {
                            withAnimation { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
                        }
                    }
                }

                // Back to live button
                if showBackToLive {
                    Button {
                        withAnimation { scrollProxy?.scrollTo("bottom-anchor", anchor: .bottom) }
                    } label: {
                        Text("Back to live ↓")
                            .font(.system(size: 12, weight: .bold, design: theme.fontDesign))
                            .foregroundColor(theme.textOnAccent)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 8)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, Spacing.sm)
                }

                // Text input bar
                TextInputBar(text: $textInput) {
                    sendMessage()
                }
                .padding(.bottom, Spacing.sm)
            }

            // Gesture layer (invisible)
            GestureLayer(
                onSingleTap: handleSingleTap,
                onDoubleTap: handleDoubleTap,
                onSwipeLeft: handleSwipeLeft,
                onSwipeRight: handleSwipeRight
            )
        }
        .statusBar(hidden: true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Actions

    private func handleSingleTap() {
        AudioServicesPlaySystemSound(1519)
        flashEffect()
        switch appState.sessionState {
        case .recording:
            sendToAI()
        case .speaking:
            appState.sessionState = .recording
        case .processing:
            break
        }
    }

    private func handleDoubleTap() {
        dismiss()
    }

    private func handleSwipeLeft() {
        switchPersona(direction: 1)
    }

    private func handleSwipeRight() {
        switchPersona(direction: -1)
    }

    private func switchPersona(direction: Int) {
        guard !appState.personas.isEmpty else { return }
        let current = appState.personas.firstIndex(where: { $0.id == appState.selectedPersonaID }) ?? 0
        let next = (current + direction + appState.personas.count) % appState.personas.count
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
        appState.selectedPersonaID = appState.personas[next].id
    }

    private func flashEffect() {
        withAnimation(.easeOut(duration: 0.15)) { flashOpacity = 0.4 }
        withAnimation(.easeOut(duration: 0.2).delay(0.15)) { flashOpacity = 0.0 }
    }

    private func sendToAI() {
        guard !appState.liveTranscript.isEmpty else { return }
        let userMsg = ChatMessage(role: .user, content: appState.liveTranscript)
        appState.activeSessionMessages.append(userMsg)
        appState.liveTranscript = ""
        appState.sessionState = .processing
        simulateAIResponse()
    }

    private func sendMessage() {
        guard !textInput.isEmpty else { return }
        let msg = ChatMessage(role: .user, content: textInput)
        appState.activeSessionMessages.append(msg)
        textInput = ""
        appState.sessionState = .processing
        simulateAIResponse()
    }

    private func simulateAIResponse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let response = ChatMessage(role: .assistant, content: "I understand. Based on what you've shared, here are my thoughts on your health question...")
            appState.activeSessionMessages.append(response)
            appState.sessionState = .speaking
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                appState.sessionState = .recording
            }
        }
    }
}

// MARK: - Top HUD

private struct TopHUD: View {
    @Environment(\.theme) var theme: AppTheme
    let statusText: String
    let statusDotColor: Color
    let personaName: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 7, height: 7)

            Text(statusText)
                .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)

            Text("·")
                .foregroundColor(theme.textSecondary)

            Text(personaName)
                .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(theme.borderSubtle, lineWidth: 0.5))
    }
}

// MARK: - Turn Block

private struct TurnBlock: View {
    @Environment(\.theme) var theme: AppTheme
    let message: ChatMessage

    var label: String {
        message.role == .user ? "YOU" : "ASSISTANT"
    }

    var labelColor: Color {
        message.role == .user ? theme.accent : theme.accentSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(labelColor)
                    .frame(width: 2, height: 12)
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: theme.fontDesign))
                    .foregroundColor(labelColor)
            }

            if message.role == .assistant {
                TypewriterText(
                    fullText: message.content,
                    font: .system(size: 22, weight: .semibold, design: theme.fontDesign),
                    color: theme.textPrimary
                )
            } else {
                Text(message.content)
                    .font(.system(size: 22, weight: .semibold, design: theme.fontDesign))
                    .foregroundColor(theme.textPrimary)
            }
        }
    }
}

// MARK: - Live Turn Block

private struct LiveTurnBlock: View {
    @Environment(\.theme) var theme: AppTheme
    let transcript: String
    let sessionState: SessionState

    @State private var cursorOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent)
                    .frame(width: 2, height: 12)
                    .opacity(cursorOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            cursorOpacity = 0.2
                        }
                    }

                Text("LIVE")
                    .font(.system(size: 12, weight: .bold, design: theme.fontDesign))
                    .foregroundColor(theme.accent)
            }

            if transcript.isEmpty {
                // Blinking cursor only
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent)
                    .frame(width: 2, height: 22)
                    .opacity(cursorOpacity)
            } else {
                LiveTranscriptText(
                    text: transcript,
                    font: .system(size: 22, weight: .semibold, design: theme.fontDesign),
                    color: theme.textPrimary
                )
            }
        }
    }
}

// MARK: - Text Input Bar

private struct TextInputBar: View {
    @Environment(\.theme) var theme: AppTheme
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Type a message...", text: $text)
                .font(.system(size: 15, weight: .regular, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(theme.surface)
                .cornerRadius(theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(theme.border, lineWidth: 0.5)
                )
                .onSubmit { onSend() }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Gesture Layer

private struct GestureLayer: View {
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { onDoubleTap() }
            )
            .simultaneousGesture(
                TapGesture(count: 1).onEnded { onSingleTap() }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -30 {
                            onSwipeLeft()
                        } else if value.translation.width > 30 {
                            onSwipeRight()
                        }
                    }
            )
    }
}
