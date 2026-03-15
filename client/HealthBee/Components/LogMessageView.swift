// LogMessageView.swift
// Health Bee — Components

import SwiftUI

struct LogMessageView: View {
    @Environment(\.theme) var theme
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.role == .user {
                Text(theme.labels.userPrefix)
                    .font(.system(size: 12, weight: theme.labelWeight, design: theme.fontDesign))
                    .foregroundColor(theme.textSecondary)
                Text(message.content)
                    .font(.system(size: 14, weight: theme.bodyWeight, design: theme.fontDesign))
                    .foregroundColor(theme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(theme.labels.assistantPrefix)
                    .font(.system(size: 12, weight: theme.labelWeight, design: theme.fontDesign))
                    .foregroundColor(theme.accentSecondary)
                Text(message.content)
                    .font(.system(size: 14, weight: theme.bodyWeight, design: theme.fontDesign))
                    .foregroundColor(theme.accent)
                    .lineSpacing(4)
                    .padding(.leading, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
