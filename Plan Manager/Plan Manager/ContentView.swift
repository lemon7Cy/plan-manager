//
//  ContentView.swift
//  Plan Manager
//
//  iOS 26 Liquid Glass Tab Bar
//

import SwiftUI
import UIKit

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(Color(hex: "0B1220").opacity(0.62))
        appearance.shadowColor = UIColor(Color.white.opacity(0.10))

        let normalColor = UIColor(Color(hex: "9FB3CF"))
        let selectedColor = UIColor(Color(hex: "66E6FF"))

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { item in
            item.normal.iconColor = normalColor
            item.normal.titleTextAttributes = [.foregroundColor: normalColor]
            item.selected.iconColor = selectedColor
            item.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @State private var selectedTab = 4
    @Environment(QuickActionManager.self) private var quickActionManager

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TabView(selection: $selectedTab) {
            FitnessView()
                .tabItem { Label("健身", systemImage: "figure.strengthtraining.traditional") }
                .tag(4)

            PlanView()
                .tabItem { Label("计划", systemImage: "calendar") }
                .tag(0)

            ExpenseView()
                .tabItem { Label("支出", systemImage: "yensign.circle") }
                .tag(1)

            WaterView()
                .tabItem { Label("喝水", systemImage: "drop") }
                .tag(2)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(DesignTokens.skyBlue)
        .onChange(of: quickActionManager.action) { _, action in
            guard let action = action else { return }
            switch action {
            case .addPlan:
                selectedTab = 0
            case .addExpense:
                selectedTab = 1
            }
        }
        .onChange(of: selectedTab) { _, _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
