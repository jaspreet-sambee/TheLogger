//
//  RingAnimations.swift
//  TheLogger
//
//  Ring-based animation components
//

import SwiftUI

// MARK: - Ring Fill Progress View

/// A circular progress ring that animates on completion with a "pop" effect
struct RingFillProgress: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let gradientColors: [Color]

    @State private var animatedProgress: Double = 0
    @State private var isComplete: Bool = false
    @State private var glowOpacity: Double = 0

    init(progress: Double, lineWidth: CGFloat = 8, gradientColors: [Color] = AppColors.accentGradient) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.gradientColors = gradientColors
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)

            // Glow effect (shows on completion)
            Circle()
                .stroke(
                    gradientColors.first?.opacity(glowOpacity) ?? AppColors.accent.opacity(glowOpacity),
                    lineWidth: lineWidth + 6
                )
                .blur(radius: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Completion checkmark
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: lineWidth * 2, weight: .bold))
                    .foregroundStyle(gradientColors.first ?? AppColors.accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isComplete ? 1.08 : 1.0)
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }

            // Trigger completion effect
            if newValue >= 1.0 && oldValue < 1.0 {
                triggerCompletionEffect()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
            if progress >= 1.0 {
                isComplete = true
            }
        }
    }

    private func triggerCompletionEffect() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Pop scale and glow
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isComplete = true
            glowOpacity = 0.6
        }

        // Fade glow
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            glowOpacity = 0
        }
    }
}

// MARK: - Set Completion Ring

/// A mini ring that pulses when a set is logged
struct SetCompletionRing: View {
    let setNumber: Int
    let isComplete: Bool

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(isComplete ? AppColors.accent : Color.secondary.opacity(0.2))
                .frame(width: 24, height: 24)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .opacity(pulse ? 0.5 : 1.0)

            if isComplete {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 24, height: 24)

                Text("\(setNumber)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Text("\(setNumber)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: isComplete) { oldValue, newValue in
            if newValue && !oldValue {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulse = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
                    pulse = false
                }
            }
        }
    }
}
