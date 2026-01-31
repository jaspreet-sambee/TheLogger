//
//  Components.swift
//  TheLogger
//
//  Reusable UI components and view modifiers
//

import SwiftUI

// MARK: - Card Style Modifier

/// A reusable card style modifier that provides consistent styling across the app.
/// Replaces duplicated card background patterns throughout the codebase.
struct CardStyle: ViewModifier {
    var borderColor: Color
    var fillOpacity: Double
    var cornerRadius: CGFloat

    init(borderColor: Color = .blue, fillOpacity: Double = 0.6, cornerRadius: CGFloat = 12) {
        self.borderColor = borderColor
        self.fillOpacity = fillOpacity
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(fillOpacity))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor.opacity(0.25), lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Applies the standard card style with customizable border color
    func cardStyle(borderColor: Color = .blue) -> some View {
        modifier(CardStyle(borderColor: borderColor))
    }

    /// Applies card style with custom parameters
    func cardStyle(borderColor: Color = .blue, fillOpacity: Double = 0.6, cornerRadius: CGFloat = 12) -> some View {
        modifier(CardStyle(borderColor: borderColor, fillOpacity: fillOpacity, cornerRadius: cornerRadius))
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
