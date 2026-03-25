//
//  AchievementCelebrationView.swift
//  TheLogger
//
//  Full-screen celebration overlay when an achievement unlocks
//

import SwiftUI

struct AchievementCelebrationView: View {
    let definition: AchievementDefinition
    let onDismiss: () -> Void

    @State private var showIcon = false
    @State private var showText = false
    @State private var showButton = false
    @State private var showConfetti = false
    @State private var iconScale: CGFloat = 0.3

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 20) {
                Spacer()

                // Achievement icon
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(tierColor.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)

                    Circle()
                        .fill(tierColor.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Circle()
                        .stroke(tierColor.opacity(0.5), lineWidth: 3)
                        .frame(width: 100, height: 100)

                    Image(systemName: definition.icon)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(tierColor)
                }
                .scaleEffect(iconScale)
                .opacity(showIcon ? 1 : 0)

                // Achievement text
                VStack(spacing: 8) {
                    Text("Achievement Unlocked!")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(tierColor)
                        .textCase(.uppercase)

                    Text(definition.name)
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(definition.description)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Text(definition.tier.rawValue)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(tierColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tierColor.opacity(0.2)))
                        .padding(.top, 4)
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(tierColor)
                        )
                }
                .padding(.horizontal, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .padding(.bottom, 40)
            }

            // Confetti
            if showConfetti {
                StreakConfettiView(isActive: true)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                showIcon = true
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showText = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.7)) {
                showButton = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
            }
        }
    }

    private var tierColor: Color {
        switch definition.tier {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return AppColors.accentGold
        case .platinum: return Color(red: 0.9, green: 0.85, blue: 1.0)
        }
    }
}

// MARK: - Achievement Unlock Toast

struct AchievementUnlockToast: View {
    let definition: AchievementDefinition
    @Binding var isVisible: Bool

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: definition.icon)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(tierColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievement Unlocked")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(tierColor)
                    Text(definition.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(tierColor.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: tierColor.opacity(0.3), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    offset = 0
                    opacity = 1
                }
                // Auto dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = -100
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isVisible = false
                    }
                }
            }
        }
    }

    private var tierColor: Color {
        switch definition.tier {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return AppColors.accentGold
        case .platinum: return Color(red: 0.9, green: 0.85, blue: 1.0)
        }
    }
}
