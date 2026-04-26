//
//  OnboardingView.swift
//  TheLogger
//
//  V2 onboarding: 8 screens leading with the 3 unique features
//  (camera rep counter, share cards, daily challenges), followed by
//  the supporting features and a setup + ready flow.
//

import SwiftUI
import AVKit

// MARK: - Helper: Locale-based unit detection

/// Returns the recommended unit system string based on device locale.
/// Exposed as a free function so unit tests can call it directly.
func recommendedUnitSystem(for locale: Locale = .current) -> String {
    if locale.measurementSystem == .metric || locale.measurementSystem == .uk {
        return "Metric"
    }
    return "Imperial"
}

// MARK: - Step model

private enum OnboardingStep: Int, CaseIterable {
    case heroCamera
    case shareCards
    case challenges
    case logging
    case restTimer
    case prsAndProgress
    case setup
    case ready

    var analyticsName: String {
        switch self {
        case .heroCamera:      return "hero_camera"
        case .shareCards:      return "share_cards"
        case .challenges:      return "challenges"
        case .logging:         return "logging"
        case .restTimer:       return "rest_timer"
        case .prsAndProgress:  return "prs_progress"
        case .setup:           return "setup"
        case .ready:           return "ready"
        }
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = true

    @State private var step: OnboardingStep = .heroCamera
    @State private var nameInput: String = ""
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            TabView(selection: $step) {
                ForEach(OnboardingStep.allCases, id: \.self) { s in
                    screenView(for: s)
                        .tag(s)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)

            // Page indicator overlay (skip on hero — full-bleed video)
            VStack {
                Spacer()
                if step != .heroCamera {
                    pageDots
                        .padding(.bottom, 8)
                }
            }
            .allowsHitTesting(false)

            // Confetti overlay (used after final CTA)
            StreakConfettiView(isActive: showConfetti)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            unitSystem = recommendedUnitSystem()
            Analytics.send(Analytics.Signal.onboardingStarted)
        }
        .onChange(of: step) { _, newValue in
            Analytics.send(Analytics.Signal.onboardingStepViewed,
                           parameters: ["step": newValue.analyticsName])
        }
    }

    // MARK: - Screen dispatcher

    @ViewBuilder
    private func screenView(for step: OnboardingStep) -> some View {
        switch step {
        case .heroCamera:     heroCameraScreen
        case .shareCards:     shareCardsScreen
        case .challenges:     challengesScreen
        case .logging:        loggingScreen
        case .restTimer:      restTimerScreen
        case .prsAndProgress: prsAndProgressScreen
        case .setup:          setupScreen
        case .ready:          readyScreen
        }
    }

    // MARK: - Page indicator

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s == step ? Color.white : Color.white.opacity(0.22))
                    .frame(width: s == step ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
            }
        }
        .accessibilityIdentifier("onboardingPageIndicator")
    }

    // MARK: - S0: Hero Camera (full-bleed video)

    private var heroCameraScreen: some View {
        ZStack(alignment: .bottom) {
            HeroVideoView(resourceName: "Squat_Rep_Counter", fileExtension: "MP4")
                .ignoresSafeArea()

            // Top fade
            LinearGradient(colors: [Color.black.opacity(0.75), .clear],
                           startPoint: .top, endPoint: .center)
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            // Bottom fade
            LinearGradient(colors: [.clear, Color.black.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

            // Top tag
            VStack {
                HStack(spacing: 8) {
                    Text("1 OF 3 UNIQUE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppColors.accentTeal)
                            .frame(width: 6, height: 6)
                            .pulsingGlow(color: AppColors.accentTeal, radius: 6)
                        Text("AI Rep Counter")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.7)
                            .foregroundStyle(AppColors.accentTeal)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppColors.accentTeal.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(AppColors.accentTeal.opacity(0.36), lineWidth: 1))
                }
                .padding(.horizontal, 22)
                .padding(.top, 56)
                Spacer()
            }
            .allowsHitTesting(false)

            // Bottom content
            VStack(alignment: .leading, spacing: 14) {
                Text("ON-DEVICE · NO INTERNET NEEDED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))

                Text("Your phone\ncounts the ")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                + Text("reps.")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(AppColors.accentTeal)

                Text("Point your camera and lift. TheLogger tracks every rep — no wearable, no account, no cloud.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(2)

                Button {
                    advance()
                } label: {
                    Text("See everything →")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15)
                            .stroke(.white.opacity(0.24), lineWidth: 1))
                }
                .accessibilityIdentifier("onboardingHeroContinue")
                .padding(.top, 6)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 70)
        }
    }

    // MARK: - S1: Share Cards (unique #2)

    private var shareCardsScreen: some View {
        let purple = Color(red: 0.69, green: 0.51, blue: 1.0)
        return FeatureScreen(
            uniquePill: ("2 of 3 unique", purple),
            kicker: ("Share the moment", purple),
            headlinePlain: "Workout cards\nworth ",
            headlineEm: "posting.",
            emColor: purple,
            screenshot: .single(name: "onboard_share", badge: ("🎬 Share", purple), tilt: -3),
            supporting: AnyView(
                ChipRow(chips: [
                    .init(label: "8 film filters", color: purple),
                    .init(label: "PR cards", color: AppColors.accentGold),
                    .init(label: "Weekly recaps", color: AppColors.accentTeal),
                    .init(label: "Stories-ready", color: AppColors.accentBlue),
                ])
            ),
            buttonTitle: "Continue",
            buttonColor: purple,
            buttonId: "onboardingShareContinue",
            buttonAction: { advance() }
        )
    }

    // MARK: - S2: Daily Challenges (unique #3)

    private var challengesScreen: some View {
        FeatureScreen(
            uniquePill: ("3 of 3 unique", AppColors.accentBlue),
            kicker: ("Daily drive", AppColors.accentBlue),
            headlinePlain: "Every day has\na ",
            headlineEm: "target.",
            emColor: AppColors.accentBlue,
            screenshot: .single(name: "onboard_challenge", badge: ("🎯 Today", AppColors.accentBlue), tilt: 0),
            supporting: AnyView(
                VStack(spacing: 8) {
                    BulletRow(icon: "🏋️", title: "Gym-day challenges",
                              subtitle: "Volume targets, PR attempts, variety", tint: AppColors.accentBlue)
                    BulletRow(icon: "🧘", title: "Rest-day challenges",
                              subtitle: "Bodyweight reps, mobility, quizzes", tint: Color(red: 0.43, green: 0.84, blue: 0.43))
                    BulletRow(icon: "🔥", title: "Keeps your streak",
                              subtitle: "A rest day still counts if you show up", tint: AppColors.accentGold)
                }
            ),
            buttonTitle: "Continue",
            buttonColor: AppColors.accentBlue,
            buttonId: "onboardingChallengesContinue",
            buttonAction: { advance() }
        )
    }

    // MARK: - S3: Fast Logging

    private var loggingScreen: some View {
        FeatureScreen(
            uniquePill: nil,
            kicker: ("Fast tracking", AppColors.accent),
            headlinePlain: "Log sets in\n",
            headlineEm: "seconds.",
            emColor: AppColors.accent,
            screenshot: .single(name: "onboard_logging2", badge: nil, tilt: 0),
            supporting: AnyView(
                ChipRow(chips: [
                    .init(label: "Pre-filled", color: AppColors.accent),
                    .init(label: "Templates", color: AppColors.accentGold),
                    .init(label: "Supersets", color: AppColors.accentBlue),
                    .init(label: "139 exercises", color: AppColors.accentTeal),
                    .init(label: "Overload advisor", color: Color(red: 0.43, green: 0.84, blue: 0.43)),
                ])
            ),
            buttonTitle: "Continue",
            buttonColor: AppColors.accent,
            buttonId: "onboardingLoggingContinue",
            buttonAction: { advance() }
        )
    }

    // MARK: - S4: Rest Timer

    private var restTimerScreen: some View {
        FeatureScreen(
            uniquePill: nil,
            kicker: ("Stay in flow", AppColors.accentGold),
            headlinePlain: "Rest auto-starts.\nZero ",
            headlineEm: "taps.",
            emColor: AppColors.accentGold,
            screenshot: .single(name: "onboard_timer", badge: nil, tilt: 0),
            supporting: AnyView(
                VStack(spacing: 8) {
                    BulletRow(icon: "⏱", title: "Auto-starts after every set",
                              subtitle: "Your rest duration, saved per exercise", tint: AppColors.accentGold)
                    BulletRow(icon: "🔒", title: "Lock screen countdown",
                              subtitle: "Live Activity + Dynamic Island", tint: AppColors.accentBlue)
                }
            ),
            buttonTitle: "Continue",
            buttonColor: AppColors.accentGold,
            buttonId: "onboardingRestTimerContinue",
            buttonAction: { advance() }
        )
    }

    // MARK: - S5: PRs + Progress

    private var prsAndProgressScreen: some View {
        FeatureScreen(
            uniquePill: nil,
            kicker: ("Celebrate + measure", AppColors.accentTeal),
            headlinePlain: "Crush records.\nTrack ",
            headlineEm: "progress.",
            emColor: AppColors.accentTeal,
            screenshot: .duo(left: ("onboard_pr",   ("🏆 PR",    AppColors.accentGold)),
                             right: ("onboard_stats", ("📊 Stats", AppColors.accentTeal))),
            supporting: AnyView(
                VStack(spacing: 8) {
                    BulletRow(icon: "🏆", title: "Auto-detects PRs",
                              subtitle: "Epley 1RM across all rep ranges · confetti", tint: AppColors.accentGold)
                    BulletRow(icon: "📈", title: "Streaks · volume · achievements",
                              subtitle: "Weekly ring, muscle balance, 30+ badges", tint: AppColors.accentTeal)
                }
            ),
            buttonTitle: "Continue",
            buttonColor: AppColors.accentTeal,
            buttonId: "onboardingPRsContinue",
            buttonAction: { advance() }
        )
    }

    // MARK: - S6: Setup

    private var setupScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Spacer().frame(height: 24)

                    Text("Quick setup")
                        .font(.system(size: 26, weight: .heavy))

                    Text("Three taps and you're in.")
                        .font(.system(.subheadline))
                        .foregroundStyle(.secondary)

                    SectionLabel("Your name (optional)")
                    TextField("What should we call you?", text: $nameInput)
                        .font(.system(.body, weight: .medium))
                        .padding(14)
                        .background(Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1.5))
                        .accessibilityIdentifier("onboardingNameField")

                    SectionLabel("Units")
                    HStack(spacing: 10) {
                        UnitPickerCard(label: "lbs", subtitle: "Imperial",
                                       isSelected: unitSystem == "Imperial",
                                       accessibilityId: "onboardingUnitLbs") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.2)) { unitSystem = "Imperial" }
                        }
                        UnitPickerCard(label: "kg", subtitle: "Metric",
                                       isSelected: unitSystem == "Metric",
                                       accessibilityId: "onboardingUnitKg") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.2)) { unitSystem = "Metric" }
                        }
                    }

                    SectionLabel("Weekly training goal")
                    HStack(spacing: 6) {
                        ForEach(2...6, id: \.self) { n in
                            GoalPill(value: n, isSelected: weeklyWorkoutGoal == n) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeOut(duration: 0.2)) { weeklyWorkoutGoal = n }
                            }
                        }
                    }

                    SectionLabel("Rest timer")
                    HStack {
                        Text("Auto-start between sets")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Toggle("", isOn: $autoStartRestTimer)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            ContinueButton(title: "Continue", color: AppColors.accent) {
                userName = nameInput.trimmingCharacters(in: .whitespaces)
                advance()
            }
            .accessibilityIdentifier("onboardingSetupContinue")
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .onAppear { if nameInput.isEmpty { nameInput = userName } }
    }

    // MARK: - S7: Ready

    private var readyScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 6) {
                        (Text("Your gym journal\nis ")
                            .foregroundStyle(.white)
                        + Text("ready.")
                            .foregroundStyle(AppColors.accent))
                            .font(.system(size: 28, weight: .heavy))
                            .multilineTextAlignment(.center)

                        Text("Everything you need to build the habit.\nAll on your device. No account.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    ScreenshotFrame(name: "onboard_home", badge: nil)
                        .frame(width: 200, height: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showConfetti = true
                    Analytics.send(Analytics.Signal.onboardingCompleted,
                                   parameters: ["cta": "letsGo", "unit": unitSystem])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text("Let's Go")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [AppColors.accentGold, Color(red: 0.83, green: 0.53, blue: 0.13)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 15))
                        .shadow(color: AppColors.accentGold.opacity(0.28), radius: 16, x: 0, y: 6)
                }
                .accessibilityIdentifier("onboardingLetsGo")

                Text("Everything stays on your device. No account, no tracking.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.22))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Navigation

    private func advance() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.35)) { step = next }
    }
}

// MARK: - Reusable feature screen layout

private enum OnboardingScreenshot {
    case single(name: String, badge: (String, Color)?, tilt: Double)
    case duo(left: (String, (String, Color)), right: (String, (String, Color)))
}

private struct FeatureScreen: View {
    let uniquePill: (String, Color)?
    let kicker: (String, Color)
    let headlinePlain: String
    let headlineEm: String
    let emColor: Color
    let screenshot: OnboardingScreenshot
    let supporting: AnyView
    let buttonTitle: String
    let buttonColor: Color
    let buttonId: String
    let buttonAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 36)

                    if let pill = uniquePill {
                        UniquePill(text: pill.0, color: pill.1)
                            .padding(.bottom, 6)
                    }

                    Text(kicker.0.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.8)
                        .foregroundStyle(kicker.1)

                    (Text(headlinePlain)
                        .foregroundStyle(.white)
                    + Text(headlineEm)
                        .foregroundStyle(emColor))
                        .font(.system(size: 26, weight: .heavy))
                        .padding(.top, 6)

                    screenshotHero
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)

                    supporting
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 22)
            }

            ContinueButton(title: buttonTitle, color: buttonColor, action: buttonAction)
                .accessibilityIdentifier(buttonId)
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var screenshotHero: some View {
        switch screenshot {
        case .single(let name, let badge, let tilt):
            ScreenshotFrame(name: name, badge: badge)
                .frame(width: 210, height: 440)
                .rotationEffect(.degrees(tilt))
        case .duo(let left, let right):
            HStack(alignment: .top, spacing: 10) {
                ScreenshotFrame(name: left.0, badge: left.1)
                    .frame(width: 140, height: 290)
                    .rotationEffect(.degrees(-2))
                    .offset(y: 8)
                ScreenshotFrame(name: right.0, badge: right.1)
                    .frame(width: 140, height: 290)
                    .rotationEffect(.degrees(2.5))
                    .offset(y: -4)
            }
        }
    }
}

// MARK: - Reusable building blocks

private struct ScreenshotFrame: View {
    let name: String
    let badge: (String, Color)?

    var body: some View {
        ZStack(alignment: .top) {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            if let (label, color) = badge {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
                    .padding(.top, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.08), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 18)
    }
}

private struct UniquePill: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

private struct ChipRow: View {
    struct Chip { let label: String; let color: Color }
    let chips: [Chip]

    var body: some View {
        FlexibleHStack(spacing: 6) {
            ForEach(chips.indices, id: \.self) { i in
                let chip = chips[i]
                HStack(spacing: 5) {
                    Circle().fill(chip.color).frame(width: 5, height: 5)
                    Text(chip.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
    }
}

private struct BulletRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.10))
                    .frame(width: 30, height: 30)
                Text(icon).font(.system(size: 14))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13)
            .stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct ContinueButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [color, color.opacity(0.78)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 15))
                .shadow(color: color.opacity(0.28), radius: 16, x: 0, y: 6)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.32))
    }
}

private struct UnitPickerCard: View {
    let label: String
    let subtitle: String
    let isSelected: Bool
    let accessibilityId: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? AppColors.accent.opacity(0.12) : Color.white.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? AppColors.accent.opacity(0.44) : Color.white.opacity(0.08), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(accessibilityId)
    }
}

private struct GoalPill: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)×")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.42))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isSelected ? AppColors.accentBlue.opacity(0.12) : Color.white.opacity(0.055),
                            in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11)
                    .stroke(isSelected ? AppColors.accentBlue.opacity(0.44) : Color.white.opacity(0.08), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("onboardingGoal\(value)")
    }
}

// MARK: - Hero video host (AVPlayerLayer for clean fullscreen loop, no controls)

private struct HeroVideoView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return view
        }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        view.looper = AVPlayerLooper(player: player, templateItem: item)
        view.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}
}

private final class PlayerContainerView: UIView {
    var looper: AVPlayerLooper?
    var player: AVQueuePlayer? {
        get { playerLayer.player as? AVQueuePlayer }
        set { playerLayer.player = newValue }
    }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override class var layerClass: AnyClass { AVPlayerLayer.self }
}

// MARK: - Flexible HStack (wraps chips to next row when needed)

private struct FlexibleHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    var body: some View {
        // Simple wrap: SwiftUI Layout API
        WrapLayout(spacing: spacing) {
            content()
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    OnboardingView()
}
