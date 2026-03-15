// ChatHistoryView.swift
// Health Bee — Session Detail

import SwiftUI

struct ChatHistoryView: View {
    @Environment(\.theme) var theme: AppTheme
    @EnvironmentObject var appState: AppState
    let session: ChatSession
    let onDismiss: () -> Void

    @State private var showActiveSession: Bool = false

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .regular, design: theme.fontDesign))
                        }
                        .foregroundColor(theme.accent)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(session.title)
                        .font(.system(size: 17, weight: .semibold, design: theme.fontDesign))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()
                        .frame(width: 60) // balance back button
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.borderSubtle)
                        .frame(height: 0.5)
                }

                // Messages
                if session.messages.isEmpty {
                    VStack {
                        Spacer()
                        Text("No messages in this session.")
                            .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                            .foregroundColor(theme.textTertiary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            ForEach(session.messages) { message in
                                LogMessageView(message: message)
                                    .padding(.horizontal, Spacing.lg)
                            }
                            Spacer(minLength: Spacing.xxl)
                        }
                        .padding(.top, Spacing.md)
                    }
                }

                // Resume button
                Button {
                    showActiveSession = true
                } label: {
                    Text(theme.labels.resumeSession)
                        .font(.system(size: 16, weight: theme.labelWeight, design: theme.fontDesign))
                        .foregroundColor(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.accent)
                        .cornerRadius(theme.cornerRadius)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(theme.background)
                .overlay(alignment: .top) {
                    Rectangle().fill(theme.borderSubtle).frame(height: 0.5)
                }
            }
        }
        .fullScreenCover(isPresented: $showActiveSession) {
            ActiveSessionView()
                .environmentObject(appState)
        }
    }
}
