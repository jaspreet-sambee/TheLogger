//
//  OnboardingView.swift
//  TheLogger
//
//  4-screen onboarding: Welcome+Name, Unit Preference, Camera Rep Counter, Privacy+CTA
//

import SwiftUI

// MARK: - Helper: Locale-based unit detection

/// Returns the recommended unit system string based on device locale.
/// Exposed as a free function so unit tests can call it directly.
func recommendedUnitSystem(for locale: Locale = .current) -> String {
    // .metric and .uk both use kilograms for body weight
    if locale.measurementSystem == .metric || locale.measurementSystem == .uk {
        return "Metric"
    }
    return "Imperial"
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @AppStorage("startWorkoutOnLaunch") private var startWorkoutOnLaunch = false

    @State private var currentStep = 0
    @State private var nameInput: String = ""
    @State private var showConfetti = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            FloatingParticlesView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator dots
                pageIndicator
                    .padding(.top, 12)

                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                            .transition(slideTransition)
                    case 1:
                        unitStep
                            .transition(slideTransition)
                    case 2:
                        cameraStep
                            .transition(slideTransition)
                    case 3:
                        privacyStep
                            .transition(slideTransition)
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: currentStep)
            }

            // Confetti overlay
            StreakConfettiView(isActive: showConfetti)
                .ignoresSafeArea()
        }
        .onAppear {
            // Auto-detect unit preference from locale
            unitSystem = recommendedUnitSystem()
        }
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(currentStep == index ? AppColors.accent : Color.secondary.opacity(0.3))
                    .frame(width: currentStep == index ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.vertical, 16)
        .accessibilityIdentifier("onboardingPageIndicator")
    }

    // MARK: - Screen 1: Welcome + Name

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // App icon
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .pulsingGlow(color: AppColors.accent, radius: 20)
                    .staggeredAppear(index: 0)
                    .accessibilityIdentifier("onboardingAppIcon")

                // Title + tagline
                VStack(spacing: 12) {
                    Text("TheLogger")
                        .font(.system(.largeTitle, weight: .bold))
                        .foregroundStyle(.primary)
                        .staggeredAppear(index: 1)

                    Text("Fast. Private. Built for the gym.")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.secondary)
                        .staggeredAppear(index: 2)
                }

                // Name input card
                VStack(spacing: 12) {
                    Text("What should we call you?")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Your name (optional)", text: $nameInput)
                        .font(.system(.body, weight: .medium))
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("onboardingNameField")
                }
                .padding(20)
                .glassMorphism(cornerRadius: 14)
                .overlay(AnimatedGradientBorder(cornerRadius: 14))
                .staggeredAppear(index: 3)
                .padding(.horizontal, 24)

                Spacer()

                // Continue button
                continueButton {
                    userName = nameInput.trimmingCharacters(in: .whitespaces)
                    advanceStep()
                }
                .accessibilityIdentifier("onboardingWelcomeContinue")
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Screen 2: Unit Preference

    private var unitStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // Icon
                OnboardingIcon(systemName: "scalemass.fill", color: AppColors.accentGold)
                    .staggeredAppear(index: 0)

                // Title
                VStack(spacing: 12) {
                    Text("How do you measure?")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .staggeredAppear(index: 1)

                    Text("Change anytime in Settings")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                        .staggeredAppear(index: 2)
                }

                // Unit picker cards
                HStack(spacing: 16) {
                    UnitPickerCard(
                        label: "lbs",
                        subtitle: "Imperial",
                        isSelected: unitSystem == "Imperial",
                        accessibilityId: "onboardingUnitLbs"
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            unitSystem = "Imperial"
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }

                    UnitPickerCard(
                        label: "kg",
                        subtitle: "Metric",
                        isSelected: unitSystem == "Metric",
                        accessibilityId: "onboardingUnitKg"
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            unitSystem = "Metric"
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .padding(.horizontal, 24)
                .staggeredAppear(index: 3)

                Spacer()

                continueButton {
                    advanceStep()
                }
                .accessibilityIdentifier("onboardingUnitContinue")
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 3: Camera Rep Counter

    private var cameraStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                // Icon
                OnboardingIcon(systemName: "camera.viewfinder", color: AppColors.accent)
                    .staggeredAppear(index: 0)

                // Title
                VStack(spacing: 12) {
                    Text("Count Reps with Your Camera")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .staggeredAppear(index: 1)

                    Text("On-device pose detection counts your reps automatically.")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .staggeredAppear(index: 2)
                }
                .padding(.horizontal, 24)

                // Feature cards
                VStack(spacing: 12) {
                    FeatureBullet(icon: "camera.fill", text: "Point your camera and start lifting", index: 3)
                    FeatureBullet(icon: "figure.walk.motion", text: "Pose detection tracks your movement", index: 4)
                    FeatureBullet(icon: "number.circle.fill", text: "Reps counted automatically", index: 5)
                    FeatureBullet(icon: "figure.mixed.cardio", text: "Squats, curls, presses & more", index: 6)
                    FeatureBullet(icon: "lock.shield", text: "All processing stays on-device", index: 7)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    continueButton {
                        advanceStep()
                    }
                    .accessibilityIdentifier("onboardingCameraContinue")

                    Button {
                        advanceStep()
                    } label: {
                        Text("Skip")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("onboardingCameraSkip")
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 4: Privacy + Get Started

    private var privacyStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                // Icon
                OnboardingIcon(systemName: "lock.shield.fill", color: AppColors.accent)
                    .staggeredAppear(index: 0)

                // Title
                Text("Your Data Stays Yours")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .staggeredAppear(index: 1)

                // Privacy bullets
                VStack(spacing: 12) {
                    PrivacyBullet(icon: "iphone", text: "All data on your device", index: 2)
                    PrivacyBullet(icon: "person.slash", text: "No accounts or tracking", index: 3)
                    PrivacyBullet(icon: "hand.raised.fill", text: "Zero data collection", index: 4)
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA buttons
                VStack(spacing: 14) {
                    // Primary: Start First Workout
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        startWorkoutOnLaunch = true
                        showConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            hasCompletedOnboarding = true
                        }
                    } label: {
                        Text("Start First Workout")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.accent)
                            .cornerRadius(12)
                    }
                    .pulsingGlow(color: AppColors.accent, radius: 12)
                    .accessibilityIdentifier("onboardingStartWorkout")

                    // Secondary: Explore First
                    Button {
                        showConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            hasCompletedOnboarding = true
                        }
                    } label: {
                        Text("Explore First")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.accent.opacity(0.5), lineWidth: 1.5)
                            )
                    }
                    .accessibilityIdentifier("onboardingExploreFirst")
                }
                .padding(.horizontal, 24)
                .staggeredAppear(index: 5)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func advanceStep() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.accent)
                .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Private Subviews

/// Circular icon with background for onboarding screens
private struct OnboardingIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 100, height: 100)

            Image(systemName: systemName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

/// Tappable unit picker card (lbs / kg)
private struct UnitPickerCard: View {
    let label: String
    let subtitle: String
    let isSelected: Bool
    let accessibilityId: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(label)
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(subtitle)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppColors.accent : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.accent : Color.white.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(accessibilityId)
        .accessibilityLabel("\(label) \(subtitle)")
    }
}

/// Feature bullet point with icon
private struct FeatureBullet: View {
    let icon: String
    let text: String
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)

            Text(text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(14)
        .cardVariant(.active)
        .staggeredAppear(index: index)
    }
}

/// Privacy bullet in card
private struct PrivacyBullet: View {
    let icon: String
    let text: String
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 28)

            Text(text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(16)
        .cardVariant(.active)
        .staggeredAppear(index: index)
    }
}

#Preview {
    OnboardingView()
}
