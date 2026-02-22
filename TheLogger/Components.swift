//
//  Components.swift
//  TheLogger
//
//  Reusable UI components and view modifiers
//

import SwiftUI

// MARK: - App Color Tokens

/// Centralized color tokens for Midnight Lift theming (deep navy + electric coral)
enum AppColors {
    static let accent: Color = Color(red: 1.0, green: 0.35, blue: 0.42)        // midnight coral
    static let accentGold: Color = Color(red: 1.0, green: 0.72, blue: 0.3)     // warm amber (success/PR)
    static let accentGradient: [Color] = [Color(red: 1.0, green: 0.25, blue: 0.38), Color(red: 1.0, green: 0.45, blue: 0.55)]
    static let background: Color = Color(red: 0.04, green: 0.05, blue: 0.12)   // midnight navy
}

// MARK: - Card Style Modifier

/// A reusable card style modifier that provides consistent styling across the app.
/// Replaces duplicated card background patterns throughout the codebase.
struct CardStyle: ViewModifier {
    var borderColor: Color
    var fillOpacity: Double
    var cornerRadius: CGFloat

    init(borderColor: Color = AppColors.accent, fillOpacity: Double = 0.06, cornerRadius: CGFloat = 12) {
        self.borderColor = borderColor
        self.fillOpacity = fillOpacity
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(fillOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor.opacity(0.25), lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Applies the standard card style with customizable border color
    func cardStyle(borderColor: Color = AppColors.accent) -> some View {
        modifier(CardStyle(borderColor: borderColor))
    }

    /// Applies card style with custom parameters
    func cardStyle(borderColor: Color = AppColors.accent, fillOpacity: Double = 0.06, cornerRadius: CGFloat = 12) -> some View {
        modifier(CardStyle(borderColor: borderColor, fillOpacity: fillOpacity, cornerRadius: cornerRadius))
    }
}

// MARK: - Card Variants

/// Context-aware card styling with subtle color hints
enum CardVariant {
    case neutral      // Default info cards
    case active       // Active workout, current exercise
    case success      // Completed sets, PRs
    case stats        // Summary statistics

    var backgroundColor: Color {
        switch self {
        case .neutral:  return Color.white.opacity(0.05)
        case .active:   return AppColors.accent.opacity(0.06)
        case .success:  return AppColors.accentGold.opacity(0.06)
        case .stats:    return AppColors.accentGold.opacity(0.05)
        }
    }

    var borderColor: Color {
        switch self {
        case .neutral:  return Color.white.opacity(0.14)
        case .active:   return AppColors.accent.opacity(0.15)
        case .success:  return AppColors.accentGold.opacity(0.18)
        case .stats:    return AppColors.accentGold.opacity(0.20)
        }
    }
}

/// Card style modifier using variants
struct VariantCardStyle: ViewModifier {
    let variant: CardVariant
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(variant.backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(variant.borderColor, lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Applies card style based on semantic variant
    func cardVariant(_ variant: CardVariant, cornerRadius: CGFloat = 12) -> some View {
        modifier(VariantCardStyle(variant: variant, cornerRadius: cornerRadius))
    }
}

// MARK: - Pressable Card Modifier

/// Adds press animation and haptic feedback to cards
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
    }
}

extension View {
    /// Makes a view pressable with scale animation and haptic
    func pressableCard() -> some View {
        self.buttonStyle(PressableStyle())
    }
}

// MARK: - Typography

/// Centralized app typography for consistent font usage
enum AppFont {
    static let headline = Font.system(.headline, weight: .semibold)
    static let body = Font.system(.body, weight: .medium)
    static let caption = Font.system(.caption, weight: .regular)
    static let title2 = Font.system(.title2, weight: .bold)
    static let title3 = Font.system(.title3, weight: .semibold)
    static let subheadline = Font.system(.subheadline, weight: .regular)
}
