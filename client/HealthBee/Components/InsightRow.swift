// InsightRow.swift
// Health Bee — Components

import SwiftUI

struct InsightRow: View {
    @Environment(\.theme) var theme: AppTheme
    let insight: Insight
    let onToggle: () -> Void

    private var icon: String {
        switch insight.type {
        case .todo: return insight.isCompleted ? "checkmark.circle.fill" : "circle"
        case .routine: return "arrow.trianglehead.2.clockwise"
        case .note: return "diamond.fill"
        case .reminder: return "bell.fill"
        }
    }

    var body: some View {
        Button(action: { if insight.type == .todo { onToggle() } }) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(insight.isCompleted ? theme.textTertiary : theme.accent)
                    .frame(width: 16)

                Text(insight.content)
                    .font(.system(size: 12, weight: theme.bodyWeight, design: theme.fontDesign))
                    .foregroundColor(insight.isCompleted ? theme.textTertiary : theme.textPrimary)
                    .strikethrough(insight.isCompleted, color: theme.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
