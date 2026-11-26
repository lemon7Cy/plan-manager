//
//  DesignSystem.swift
//  Plan Manager
//
//  Professional Design System - Liquid Glass Theme
//  Style: Soft / Glass | Colors: Sky Blue + Cyan + Neutral Gray
//

import SwiftUI

// MARK: - Design Tokens

struct DesignTokens {
    // Primary Colors - Clean Minimal (Updated)
    static let primary = Color(hex: "4C8DFF")         // Vivid Blue - Main Theme
    static let primaryLight = Color(hex: "9CC5FF")    // Light Blue
    static let primaryDark = Color(hex: "2F62D6")     // Deep Blue

    // Supporting Colors
    static let secondary = Color(hex: "FFC247")       // Warm Amber
    static let secondaryLight = Color(hex: "FFE8B3")  // Light Amber

    // Accent Colors
    static let accentMint = Color(hex: "2FD49B")      // Mint Green
    static let accentCyan = Color(hex: "5CCDE8")      // Soft Cyan

    // === Clean Minimal Palette (Matching Reference Image) ===
    static let cleanBlue = Color(hex: "4C8DFF")
    static let cleanGray = Color(hex: "8E8E93")       // System Gray
    static let cleanLightGray = Color(hex: "F5F5F0")  // Cream White (奶白色)
    static let cleanDarkGray = Color(hex: "1C1C1E")   // Dark Background
    static let cyanGray = Color(hex: "5B7B7A")        // Cyan-Gray (青灰色) - Legacy
    static let skyBlue = Color(hex: "4C8DFF")

    // Background Colors (Matching Reference Image)
    static let backgroundLight = Color(hex: "F2F7FF")
    static let backgroundDark = Color(hex: "0A1220")

    // Text Colors - High Contrast
    static let textPrimaryLight = Color(hex: "000000") // Pure Black
    static let textPrimaryDark = Color(hex: "FFFFFF")  // Pure White
    static let textSecondaryLight = Color(hex: "8E8E93") // System Gray
    static let textSecondaryDark = Color(hex: "8E8E93") // System Gray

    // Semantic Colors
    static let success = Color(hex: "34C759")  // Apple Green
    static let warning = Color(hex: "FF9500")  // Apple Orange
    static let error = Color(hex: "FF3B30")    // Apple Red
    static let info = Color(hex: "007AFF")     // Apple Blue

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacing2XL: CGFloat = 48

    // Border Radius - Slightly Squarer but still rounded
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radius2XL: CGFloat = 28

    // Borders (Legacy for Neo-Brutalism)
    static let strokeWidth: CGFloat = 2.0

    // === Clean Minimal Shadows ===
    static func softShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.10)
    }

    // Legacy Hard Pop Shadows
    static func cardShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.black
    }

    static func floatingShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.2) : Color.black
    }
}

// MARK: - Adaptive Colors

struct AppThemeColors {
    let colorScheme: ColorScheme

    var background: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(hex: "0A1220"), Color(hex: "101B2E"), Color(hex: "0D2B3A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "315B9D").opacity(0.25))
                    .frame(width: 360, height: 360)
                    .blur(radius: 48)
                    .offset(x: -120, y: -220)

                Circle()
                    .fill(Color(hex: "32C7C0").opacity(0.18))
                    .frame(width: 300, height: 300)
                    .blur(radius: 52)
                    .offset(x: 150, y: 260)
            } else {
                LinearGradient(
                    colors: [Color(hex: "EFF6FF"), Color(hex: "E9F3FF"), Color(hex: "F4FBFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "8CB8FF").opacity(0.18))
                    .frame(width: 360, height: 360)
                    .blur(radius: 50)
                    .offset(x: -140, y: -240)

                Circle()
                    .fill(Color(hex: "74E2D2").opacity(0.14))
                    .frame(width: 320, height: 320)
                    .blur(radius: 54)
                    .offset(x: 160, y: 240)
            }
        }
    }

    var surface: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.74)
    }

    var textPrimary: Color {
        colorScheme == .dark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight
    }

    var textSecondary: Color {
        colorScheme == .dark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight
    }

    var cardBackground: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color(hex: "1E1E1E"))
            : AnyShapeStyle(Color.white)
    }
}

// MARK: - Color Extension

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

    var hex: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0]
        let r = Int(components[0] * 255)
        let g = Int(components.count > 1 ? components[1] * 255 : 0)
        let b = Int(components.count > 2 ? components[2] * 255 : 0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Theme Environment Key

struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppThemeColors(colorScheme: .light)
}

extension EnvironmentValues {
    var themeColors: AppThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - Custom Button Styles

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(DesignTokens.primary)
            .clipShape(Capsule())
            .shadow(color: DesignTokens.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundColor(.black)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(DesignTokens.secondary)
            .clipShape(Capsule())
            .shadow(color: DesignTokens.secondary.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card Modifier

struct DesignCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = DesignTokens.spacingMD
    var backgroundColor: Color = .white

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusXL)
                    .fill(colorScheme == .dark ? Color(hex: "1E1E1E") : backgroundColor)
                    .shadow(color: DesignTokens.softShadow(for: colorScheme), radius: 12, x: 0, y: 6)
            )
    }
}

extension View {
    func designCard(padding: CGFloat = DesignTokens.spacingMD, backgroundColor: Color? = nil) -> some View {
        if let color = backgroundColor {
            return modifier(DesignCard(padding: padding, backgroundColor: color))
        } else {
             return modifier(DesignCard(padding: padding))
        }
    }

    /// Clean Minimal card style - soft shadows, no borders
    func cleanCard(padding: CGFloat = DesignTokens.spacingMD) -> some View {
        modifier(CleanCard(padding: padding))
    }
}

// MARK: - Clean Minimal Card Modifier

struct CleanCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = DesignTokens.spacingMD

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.64), lineWidth: 1)
                    )
                    .shadow(
                        color: DesignTokens.softShadow(for: colorScheme),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            )
    }
}

// MARK: - Micro-interaction Animations

extension Animation {
    static var microBounce: Animation {
        .spring(response: 0.3, dampingFraction: 0.6)
    }

    static var microSmooth: Animation {
        .easeInOut(duration: 0.3)
    }

    static var microSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.7)
    }
}

// MARK: - Progress Ring

struct ProgressRingView: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let gradient: LinearGradient

    @Environment(\.colorScheme) private var colorScheme

    init(
        progress: Double,
        size: CGFloat = 60,
        lineWidth: CGFloat = 6,
        gradient: LinearGradient = LinearGradient(
            colors: [DesignTokens.primary, DesignTokens.accentCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    ) {
        self.progress = min(max(progress, 0), 1)
        self.size = size
        self.lineWidth = lineWidth
        self.gradient = gradient
    }

    var body: some View {
        ZStack {
            // Background Track
            Circle()
                .stroke(
                    DesignTokens.primary.opacity(0.1),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: DesignTokens.primary.opacity(0.3), radius: 4, y: 0)
                .animation(.microSpring, value: progress)

            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundColor(colorScheme == .dark ? DesignTokens.textPrimaryDark : DesignTokens.textPrimaryLight)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    var color: Color = DesignTokens.primary // Default color
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.black))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(color)
                    : AnyShapeStyle(Color.white)
            )
            .foregroundColor(isSelected ? .black : .black) // Always black text for pop
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black, lineWidth: DesignTokens.strokeWidth)
            )
            .shadow(color: isSelected ? .black : .clear, radius: 0, x: isSelected ? 4 : 0, y: isSelected ? 4 : 0)
            .offset(x: isSelected ? 0 : 2, y: isSelected ? 0 : 2) // Subtle depressed state when not selected? Or opposite?
        }
        .animation(nil, value: isSelected)
    }
}

// MARK: - Playbook Components

struct PMGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.58), lineWidth: 1)
                    )
                    .shadow(color: DesignTokens.softShadow(for: colorScheme), radius: 10, x: 0, y: 5)
            )
    }
}

struct PMPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(DesignTokens.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
            )
            .shadow(color: DesignTokens.primary.opacity(0.35), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

struct PMOfflineBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "08111F"), Color(hex: "0E1B2C"), Color(hex: "102A36")]
                    : [Color(hex: "F5FAFF"), Color(hex: "EDF5FF"), Color(hex: "F8FCFF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(DesignTokens.skyBlue.opacity(colorScheme == .dark ? 0.16 : 0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 46)
                .offset(x: -150, y: -240)
                .allowsHitTesting(false)

            Circle()
                .fill(DesignTokens.accentMint.opacity(colorScheme == .dark ? 0.10 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 170, y: 260)
                .allowsHitTesting(false)
        }
    }
}

struct PMIconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: Circle())
    }
}

struct PMStatChip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PMTopBar<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
