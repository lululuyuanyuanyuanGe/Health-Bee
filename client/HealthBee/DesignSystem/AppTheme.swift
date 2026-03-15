// AppTheme.swift
// Health Bee — Design System
// Color, typography, spacing, and corner radius tokens

import SwiftUI

// MARK: - AppTheme

struct AppTheme {
    // MARK: Colors
    let background: Color
    let surface: Color
    let surfaceSecondary: Color
    let surfaceTertiary: Color
    let accent: Color
    let accentSecondary: Color
    let destructive: Color
    let success: Color
    let warning: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textOnAccent: Color
    let border: Color
    let borderSubtle: Color
    let iconPrimary: Color
    let iconSecondary: Color
    let userMessageBg: Color

    // MARK: Typography
    let headingWeight: Font.Weight
    let bodyWeight: Font.Weight
    let labelWeight: Font.Weight
    let fontDesign: Font.Design

    // MARK: Corner Radius
    let radiusSM: CGFloat
    let radiusMD: CGFloat
    let radiusLG: CGFloat
    let radiusFull: CGFloat

    var cornerRadius: CGFloat { radiusMD }

    // MARK: Color Scheme
    let colorScheme: ColorScheme

    // MARK: Labels
    let labels: ThemeLabels
}

// MARK: - ThemeLabels

struct ThemeLabels {
    let sessionsTab = "Sessions"
    let homeTab = "Home"
    let settingsTab = "Settings"
    let personaLabel = "Background"
    let intelLabel = "Recent"
    let noIntelText = "No recent activity"
    let deployDuo = "Tap to start"
    let deploySolo = "Tap to start solo"
    let listeningStatus = "Listening"
    let processingStatus = "Thinking..."
    let speakingStatus = "Speaking"
    let userPrefix = "You"
    let assistantPrefix = "Assistant"
    let linkedBadge = "Connected"
    let activeBadge = "Active"
    let resumeSession = "Resume"
    let selectPersona = "Choose assistant"
    let neuralUplinks = "Integrations"
}

// MARK: - Predefined Themes

extension AppTheme {
    static let dark = AppTheme(
        background: Color(hex: "#000000"),
        surface: Color(hex: "#0D0D0D"),
        surfaceSecondary: Color(hex: "#1A1A1A"),
        surfaceTertiary: Color(hex: "#2A2A2A"),
        accent: Color(hex: "#FFFFFF"),
        accentSecondary: Color(hex: "#9B9B9B"),
        destructive: Color(hex: "#FF3B30"),
        success: Color(hex: "#34C759"),
        warning: Color(hex: "#FF9500"),
        textPrimary: Color(hex: "#FFFFFF"),
        textSecondary: Color(hex: "#9B9B9B"),
        textTertiary: Color(hex: "#666666"),
        textOnAccent: Color(hex: "#000000"),
        border: Color(hex: "#2A2A2A"),
        borderSubtle: Color(hex: "#1A1A1A"),
        iconPrimary: Color(hex: "#FFFFFF"),
        iconSecondary: Color(hex: "#9B9B9B"),
        userMessageBg: Color(hex: "#2A2A2A"),
        headingWeight: .bold,
        bodyWeight: .regular,
        labelWeight: .medium,
        fontDesign: .default,
        radiusSM: 8,
        radiusMD: 12,
        radiusLG: 16,
        radiusFull: 999,
        colorScheme: .dark,
        labels: ThemeLabels()
    )

    static let light = AppTheme(
        background: Color(hex: "#FFFFFF"),
        surface: Color(hex: "#F7F7F8"),
        surfaceSecondary: Color(hex: "#F0F0F0"),
        surfaceTertiary: Color(hex: "#E8E8E8"),
        accent: Color(hex: "#0D0D0D"),
        accentSecondary: Color(hex: "#6E6E80"),
        destructive: Color(hex: "#FF3B30"),
        success: Color(hex: "#34C759"),
        warning: Color(hex: "#FF9500"),
        textPrimary: Color(hex: "#0D0D0D"),
        textSecondary: Color(hex: "#6E6E80"),
        textTertiary: Color(hex: "#ACACBE"),
        textOnAccent: Color(hex: "#FFFFFF"),
        border: Color(hex: "#E5E5E5"),
        borderSubtle: Color(hex: "#ECECEC"),
        iconPrimary: Color(hex: "#0D0D0D"),
        iconSecondary: Color(hex: "#6E6E80"),
        userMessageBg: Color(hex: "#F7F7F8"),
        headingWeight: .bold,
        bodyWeight: .regular,
        labelWeight: .medium,
        fontDesign: .default,
        radiusSM: 8,
        radiusMD: 12,
        radiusLG: 16,
        radiusFull: 999,
        colorScheme: .light,
        labels: ThemeLabels()
    )
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
