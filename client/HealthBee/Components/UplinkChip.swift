// UplinkChip.swift
// Health Bee — Components

import SwiftUI

struct UplinkChip: View {
    @Environment(\.theme) var theme
    let icon: String
    let name: String
    let isOnline: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(isOnline ? theme.accent : theme.textTertiary)

            Text(name)
                .font(.system(size: 11, weight: theme.labelWeight, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            Circle()
                .fill(isOnline ? theme.success : theme.textTertiary.opacity(0.4))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
        .cornerRadius(theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }
}
