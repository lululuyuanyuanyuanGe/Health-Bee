// DashboardCardRow.swift
// Health Bee — Components

import SwiftUI

struct DashboardCardRow: View {
    @Environment(\.theme) var theme: AppTheme
    let card: DashboardCard

    private var icon: String {
        switch card.type {
        case .reminder: return "bell.fill"
        case .social: return "person.2.fill"
        case .insight: return "lightbulb.fill"
        case .discover: return "safari.fill"
        case .tip: return "sparkles"
        }
    }

    private var iconColor: Color {
        switch card.type {
        case .reminder: return theme.warning
        case .social: return theme.accent
        case .insight: return theme.textPrimary
        case .discover: return theme.accentSecondary
        case .tip: return theme.accent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(iconColor)
                .frame(width: 16)

            Text(card.content)
                .font(.system(size: 12, weight: theme.bodyWeight, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
