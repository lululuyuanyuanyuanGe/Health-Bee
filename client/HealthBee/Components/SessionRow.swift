// SessionRow.swift
// Health Bee — Components

import SwiftUI

struct SessionRow: View {
    @Environment(\.theme) var theme: AppTheme
    let session: ChatSession
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .medium, design: theme.fontDesign))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Text(session.preview)
                        .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(session.date.relativeShortString())
                    .font(.system(size: 13, weight: .regular, design: theme.fontDesign))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
