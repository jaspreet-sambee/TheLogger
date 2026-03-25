//
//  ViewModifiers.swift
//  TheLogger
//
//  Reusable view modifiers and small decorative views
//

import SwiftUI

// MARK: - Pulsing Glow Modifier

/// Adds a pulsing glow effect to any view
struct PulsingGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isPulsing ? 0.6 : 0.2), radius: isPulsing ? radius : radius/2)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulsingGlow(color: Color, radius: CGFloat = 15) -> some View {
        modifier(PulsingGlow(color: color, radius: radius))
    }
}

// MARK: - Animated Flame

/// A flame icon that periodically bounces for streak display
struct AnimatedFlame: View {
    let color: Color
    @State private var isAnimating = false
    @State private var timer: Timer?

    init(color: Color = AppColors.accent) {
        self.color = color
    }

    var body: some View {
        Image(systemName: "flame.fill")
            .foregroundStyle(color)
            .symbolEffect(.bounce, value: isAnimating)
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                    isAnimating.toggle()
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

// MARK: - Week Dots

/// Shows 7 dots representing days of the week, highlighting workout days
struct WeekDots: View {
    let workoutDays: Set<Int>  // 0-6, where 0 = Sunday
    let accentColor: Color

    init(workoutDays: Set<Int>, accentColor: Color = .purple) {
        self.workoutDays = workoutDays
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { day in
                Circle()
                    .fill(workoutDays.contains(day) ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Animated Stat Card

/// A stat card with counting animation and optional badge
struct AnimatedStatCard<Icon: View>: View {
    let icon: Icon
    let value: Int
    let label: String
    let color: Color
    var badge: String? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                icon
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(color)

                CountingNumber(value: appeared ? value : 0)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.15))
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }
}

// MARK: - Staggered Appear Modifier

/// Adds a staggered fade-in and slide-up animation with spring physics
struct StaggeredAppear: ViewModifier {
    let index: Int
    let maxStagger: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .scaleEffect(appeared ? 1 : 0.95)
            .onAppear {
                let delay = Double(min(index, maxStagger)) * 0.06
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, maxStagger: Int = 5) -> some View {
        modifier(StaggeredAppear(index: index, maxStagger: maxStagger))
    }
}

// MARK: - Button Press Scale Modifier

/// Adds a satisfying press scale effect to tappable elements
struct ButtonPressScale: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    init(scale: CGFloat = 0.97) {
        self.scale = scale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func pressScale(_ scale: CGFloat = 0.97) -> some View {
        modifier(ButtonPressScale(scale: scale))
    }
}

// MARK: - Smooth Content Transition

/// Adds smooth content transition for changing values
struct SmoothValueTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
    }
}

// MARK: - Glass Morphism Modifier

/// Adds a frosted glass effect to any view
struct GlassMorphism: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(intensity)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassMorphism(cornerRadius: CGFloat = 12, intensity: Double = 0.8) -> some View {
        modifier(GlassMorphism(cornerRadius: cornerRadius, intensity: intensity))
    }
}
