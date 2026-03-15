// TypographyModifiers.swift
// Health Bee — Design System
// View modifier shortcuts for the type scale

import SwiftUI

// MARK: - Theme Typography Modifiers

extension View {
    func themeHeading(theme: AppTheme, size: CGFloat = 24) -> some View {
        self.font(.system(size: size, weight: theme.headingWeight, design: theme.fontDesign))
            .foregroundColor(theme.textPrimary)
            .tracking(0)
    }

    func themeBody(theme: AppTheme, color: Color? = nil, size: CGFloat = 16) -> some View {
        self.font(.system(size: size, weight: theme.bodyWeight, design: theme.fontDesign))
            .foregroundColor(color ?? theme.textPrimary)
    }

    func themeLabel(theme: AppTheme, color: Color? = nil, size: CGFloat = 12) -> some View {
        self.font(.system(size: size, weight: theme.labelWeight, design: theme.fontDesign))
            .foregroundColor(color ?? theme.textSecondary)
    }
}

// MARK: - Spacing Tokens

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
