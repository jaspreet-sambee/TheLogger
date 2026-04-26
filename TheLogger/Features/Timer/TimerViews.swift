//
//  TimerViews.swift
//  TheLogger
//
//  Rest timer and PR celebration views
//

import SwiftUI

// MARK: - Rest Timer View (Gold Ring Countdown Hero)
struct RestTimerView: View {
    let exerciseId: UUID
    private let timer = RestTimerManager.shared
    @State private var completeBounceTrigger = false
    @State private var entranceScale: CGFloat = 0.85
    @State private var entranceOpacity: Double = 0
    @State private var countdownPulse: CGFloat = 1.0
    @State private var lastSecond: Int = -1

    private let goldColor = AppColors.accentGold

    private var formattedSuggestedTime: String {
        let m = timer.suggestedDuration / 60
        let s = timer.suggestedDuration % 60
        return s == 0 ? "\(m):00" : String(format: "%d:%02d", m, s)
    }

    var body: some View {
        if timer.shouldShowFor(exerciseId: exerciseId) {
            Group {
                if timer.isOfferingRestFor(exerciseId: exerciseId) {
                    restOptionView
                } else if timer.isComplete {
                    completedView
                } else if timer.isActiveFor(exerciseId: exerciseId) {
                    activeTimerView
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(heroContainer)
            .scaleEffect(entranceScale)
            .opacity(entranceOpacity)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: timer.isActive)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: timer.isComplete)
            .onChange(of: timer.isComplete) { _, c in if !c { completeBounceTrigger = false } }
            .onChange(of: timer.remainingSeconds) { _, v in
                if timer.isActive && v != lastSecond { lastSecond = v; triggerPulse() }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    entranceScale = 1.0; entranceOpacity = 1.0
                }
            }
            .onDisappear { entranceScale = 0.85; entranceOpacity = 0 }
        }
    }

    // MARK: - Hero Container (gold tinted, matching LOG SET shape)

    private var heroContainer: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(goldColor.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(goldColor.opacity(0.16), lineWidth: 1)
            )
    }

    // MARK: - Rest Option (before starting timer)

    private var restOptionView: some View {
        VStack(spacing: 14) {
            // Start button
            Button { timer.start() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Rest")
                        .font(.system(size: 15, weight: .bold))
                    Text(formattedSuggestedTime)
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(goldColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(goldColor.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(goldColor.opacity(0.25), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            // Duration presets
            HStack(spacing: 6) {
                ForEach([30, 60, 90, 120, 150, 180], id: \.self) { secs in
                    let sel = timer.suggestedDuration == secs
                    Button { timer.setSuggestedDuration(secs) } label: {
                        Text(formatPreset(secs))
                            .font(.system(size: 12, weight: sel ? .bold : .medium))
                            .foregroundStyle(sel ? goldColor : Color.white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(sel ? goldColor.opacity(0.15) : Color.white.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Dismiss
            Button { timer.dismiss() } label: {
                Text("Skip Rest")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Active Timer (ring countdown)

    private var activeTimerView: some View {
        VStack(spacing: 14) {
            // Ring + countdown
            ZStack {
                // Background ring
                Circle()
                    .stroke(goldColor.opacity(0.12), lineWidth: 6)
                    .frame(width: 100, height: 100)

                // Progress ring
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: goldColor.opacity(0.4), radius: 4)
                    .animation(.linear(duration: 1.0), value: timer.progress)

                // Time + label
                VStack(spacing: 2) {
                    Text(timer.formattedTime)
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .scaleEffect(countdownPulse)
                        .contentTransition(.numericText(value: Double(timer.remainingSeconds)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timer.remainingSeconds)
                    Text("Resting")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button { timer.addSeconds(30) } label: {
                    Text("+ 30s")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(goldColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(goldColor.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(goldColor.opacity(0.25), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Button { timer.skip() } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(goldColor)
                .symbolEffect(.bounce, value: completeBounceTrigger)
            Text("Rest complete")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear { completeBounceTrigger = true }
    }

    // MARK: - Helpers

    private func formatPreset(_ seconds: Int) -> String {
        let m = seconds / 60; let s = seconds % 60
        return s == 0 ? "\(m):00" : String(format: "%d:%02d", m, s)
    }

    private func triggerPulse() {
        let intensity: CGFloat = timer.remainingSeconds <= 5 ? 1.08 : 1.03
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { countdownPulse = intensity }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { countdownPulse = 1.0 }
        }
    }
}

// MARK: - PR Celebration View
// MARK: - PR Celebration Data

struct PRCelebrationData {
    let exerciseName: String
    let weight: Double      // storage units (lbs)
    let reps: Int
    let estimated1RM: Double // storage units
    let previousWeight: Double?
    let previousReps: Int?
    let previous1RM: Double?
    let isBodyweight: Bool
}

// MARK: - PR Celebration Card (rich, matches mockup)

struct PRCelebrationCard: View {
    let data: PRCelebrationData
    var onDismiss: () -> Void

    @State private var appeared = false
    private let gold = Color(red: 0.91, green: 0.66, blue: 0.20)

    var body: some View {
        VStack(spacing: 0) {
            // Trophy + badge
            VStack(spacing: 14) {
                // Gold glow behind trophy
                ZStack {
                    Circle()
                        .fill(gold.opacity(0.15))
                        .frame(width: 96, height: 96)
                        .blur(radius: 12)

                    Circle()
                        .stroke(gold.opacity(0.25), lineWidth: 2)
                        .frame(width: 88, height: 88)

                    Text("🏆")
                        .font(.system(size: 44))
                        .scaleEffect(appeared ? 1.0 : 0.3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5), value: appeared)
                }

                // Badge
                HStack(spacing: 6) {
                    Text("✦")
                        .font(.system(size: 10))
                        .foregroundStyle(gold)
                    Text("NEW PERSONAL RECORD")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(gold)
                        .tracking(1.2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(gold.opacity(0.15))
                        .overlay(Capsule().stroke(gold.opacity(0.35), lineWidth: 1))
                )
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Exercise name
            Text(data.exerciseName.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(2)
                .padding(.bottom, 8)

            // Weight (hero number)
            if data.isBodyweight {
                Text("BW")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(.white)
            } else {
                let displayWeight = UnitFormatter.convertToDisplay(data.weight)
                let weightStr = displayWeight.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(displayWeight))" : String(format: "%.1f", displayWeight)
                Text(weightStr)
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(-3)
            }

            // Reps + unit
            HStack(spacing: 4) {
                if !data.isBodyweight {
                    Text(UnitFormatter.weightUnit)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                }
                Text("×")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                Text("\(data.reps) reps")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
            .padding(.top, 2)

            // Estimated 1RM
            if data.estimated1RM > 0 {
                let display1RM = UnitFormatter.convertToDisplay(data.estimated1RM)
                HStack(spacing: 4) {
                    Text("Est. 1RM")
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text("\(Int(display1RM)) \(UnitFormatter.weightUnit)")
                        .foregroundStyle(Color.white.opacity(0.7))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14))
                .padding(.top, 6)
            }

            // Previous PR comparison
            if let prevWeight = data.previousWeight, let prevReps = data.previousReps {
                let displayPrev = UnitFormatter.convertToDisplay(prevWeight)
                let prev1RMStr = data.previous1RM.map { "\(Int(UnitFormatter.convertToDisplay($0))) \(UnitFormatter.weightUnit) 1RM" } ?? ""
                Text("Previous: \(Int(displayPrev)) \(UnitFormatter.weightUnit) × \(prevReps)" + (prev1RMStr.isEmpty ? "" : " · \(prev1RMStr)"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(.top, 4)
            }

            // Divider
            Rectangle()
                .fill(gold.opacity(0.25))
                .frame(width: 40, height: 1)
                .padding(.vertical, 18)

            // Keep Going button
            Button(action: onDismiss) {
                Text("Keep Going")
                    .font(.system(.body, weight: .heavy))
                    .foregroundStyle(Color(red: 0.10, green: 0.06, blue: 0.0))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [Color(red: 0.94, green: 0.72, blue: 0.20), Color(red: 0.83, green: 0.53, blue: 0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            // Top shine
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(red: 0.83, green: 0.53, blue: 0.12).opacity(0.45), radius: 14, y: 6)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.086, green: 0.075, blue: 0.059).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(gold.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: gold.opacity(0.15), radius: 40)
                .shadow(color: .black.opacity(0.7), radius: 30, y: 20)
        )
        .onAppear { appeared = true }
    }
}

// Legacy — kept for backward compatibility
struct PRCelebrationView: View {
    var body: some View {
        PRCelebrationCard(
            data: PRCelebrationData(
                exerciseName: "Exercise",
                weight: 0, reps: 0, estimated1RM: 0,
                previousWeight: nil, previousReps: nil, previous1RM: nil,
                isBodyweight: true
            ),
            onDismiss: {}
        )
    }
}

// MARK: - Confetti View (pure SwiftUI)
struct ConfettiView: View {
    private let particleCount = 28
    private let colors: [Color] = [.yellow, .orange, .white, Color(white: 0.95)]

    @State private var launched = false

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            ZStack {
                ForEach(0..<particleCount, id: \.self) { i in
                    let dx = CGFloat((i % 9) - 4) * 36
                    let dy = 80 + CGFloat(i % 7) * 35
                    let delay = Double(i) * 0.022
                    let color = colors[i % colors.count]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.9))
                        .frame(width: 6, height: 10)
                        .rotationEffect(.degrees(launched ? Double((i % 5) - 2) * 72 : 0))
                        .offset(x: dx + (launched ? CGFloat((i % 3) - 1) * 60 : 0),
                                y: launched ? dy + 280 : 0)
                        .opacity(launched ? 0 : 1)
                        .animation(.easeOut(duration: 1.6).delay(delay), value: launched)
                }
            }
            .position(x: cx, y: cy - 60)
        }
        .allowsHitTesting(false)
        .onAppear {
            launched = true
        }
    }
}
