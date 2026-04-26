//
//  Components.swift
//  TheLogger
//
//  Reusable UI components and view modifiers
//

import SwiftUI

// MARK: - Debug Logging

/// Logs a message to the console in DEBUG builds only. No-op in release.
func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

// MARK: - App Color Tokens

/// Centralized color tokens for TheLogger theming (neutral near-black + saturated red)
enum AppColors {
    static let accent: Color = Color(red: 0.91, green: 0.22, blue: 0.29)        // saturated red #E8384A
    static let accentGold: Color = Color(red: 1.0, green: 0.72, blue: 0.3)     // warm amber (success/PR)
    static let accentBlue: Color = Color(red: 0.5, green: 0.65, blue: 1.0)    // periwinkle — reps
    static let accentTeal: Color = Color(red: 0.3, green: 0.78, blue: 0.72)   // teal — workouts/duration
    static let accentGradient: [Color] = [Color(red: 0.91, green: 0.22, blue: 0.29), Color(red: 1.0, green: 0.35, blue: 0.19)]  // red → orange
    static let background: Color = Color(red: 0.039, green: 0.039, blue: 0.059)  // neutral near-black #0A0A0F
}

// MARK: - Card Style Modifier

/// A reusable card style modifier that provides consistent styling across the app.
/// Replaces duplicated card background patterns throughout the codebase.
struct CardStyle: ViewModifier {
    var borderColor: Color
    var fillOpacity: Double
    var cornerRadius: CGFloat

    init(borderColor: Color = AppColors.accent, fillOpacity: Double = 0.04, cornerRadius: CGFloat = 18) {
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
                            .stroke(borderColor.opacity(0.20), lineWidth: 1)
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
    func cardStyle(borderColor: Color = AppColors.accent, fillOpacity: Double = 0.04, cornerRadius: CGFloat = 18) -> some View {
        modifier(CardStyle(borderColor: borderColor, fillOpacity: fillOpacity, cornerRadius: cornerRadius))
    }
}

// MARK: - Tinted Card Style

/// A card style with a gradient tint background — used for dashboard cards that need visual distinction.
struct TintedCardStyle: ViewModifier {
    var tintColor: Color
    var secondaryTint: Color?
    var borderColor: Color
    var cornerRadius: CGFloat

    init(tintColor: Color, secondaryTint: Color? = nil, borderColor: Color? = nil, cornerRadius: CGFloat = 18) {
        self.tintColor = tintColor
        self.secondaryTint = secondaryTint
        self.borderColor = borderColor ?? tintColor
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                tintColor.opacity(0.10),
                                (secondaryTint ?? tintColor).opacity(0.04),
                                Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor.opacity(0.20), lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Applies a tinted gradient card style — each card gets a unique color identity
    func tintedCardStyle(tint: Color, secondaryTint: Color? = nil, border: Color? = nil) -> some View {
        modifier(TintedCardStyle(tintColor: tint, secondaryTint: secondaryTint, borderColor: border))
    }
}

// MARK: - Gradient CTA Button Style

/// Premium gradient CTA button — red→orange fill with top shine and glow shadow
struct GradientCTAStyle: ViewModifier {
    var height: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: AppColors.accentGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: AppColors.accent.opacity(0.45), radius: 14, y: 6)
    }
}

extension View {
    func gradientCTA(height: CGFloat = 52, cornerRadius: CGFloat = 14) -> some View {
        modifier(GradientCTAStyle(height: height, cornerRadius: cornerRadius))
    }
}

// MARK: - Gold Card Style

/// Gold-tinted card for PRs, achievements, and success states
extension View {
    func goldCardStyle() -> some View {
        modifier(CardStyle(borderColor: AppColors.accentGold, fillOpacity: 0.05, cornerRadius: 18))
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
