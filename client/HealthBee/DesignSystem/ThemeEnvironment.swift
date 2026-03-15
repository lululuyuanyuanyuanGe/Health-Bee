// ThemeEnvironment.swift
// Health Bee — Design System
// Environment key, ThemeManager, ThemeResolver

import SwiftUI

// MARK: - Environment Key

struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system
    case dark
    case light

    var displayName: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// MARK: - ThemeManager

final class ThemeManager: ObservableObject {
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: stored) ?? .system
    }
}

// MARK: - ThemeResolver ViewModifier

struct ThemeResolver: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    var resolvedScheme: ColorScheme {
        switch themeManager.appearanceMode {
        case .system: return colorScheme
        case .dark: return .dark
        case .light: return .light
        }
    }

    func body(content: Content) -> some View {
        let theme: AppTheme = resolvedScheme == .dark ? .dark : .light
        content
            .environment(\.theme, theme)
            .preferredColorScheme(themeManager.appearanceMode.colorScheme)
    }
}

extension View {
    func applyTheme() -> some View {
        self.modifier(ThemeResolver())
    }
}
