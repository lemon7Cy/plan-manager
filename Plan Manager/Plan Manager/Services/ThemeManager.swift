//
//  ThemeManager.swift
//  Plan Manager
//
//  Theme management for light/dark/auto modes
//

import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "auto"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
@Observable
final class ThemeManager: @unchecked Sendable {
    var currentTheme: AppTheme = .dark

    init() {
        loadTheme()
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: StorageKeys.appTheme)
    }

    func reloadTheme() {
        loadTheme()
    }

    private func loadTheme() {
        if let saved = UserDefaults.standard.string(forKey: StorageKeys.appTheme),
           let theme = AppTheme(rawValue: saved) {
            currentTheme = theme
        }
    }
}
