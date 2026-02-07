//
//  TimerViews.swift
//  TheLogger
//
//  Rest timer and PR celebration views
//

import SwiftUI

// MARK: - Rest Timer View
struct RestTimerView: View {
    let exerciseId: UUID
    private let timer = RestTimerManager.shared
    @State private var completeBounceTrigger = false
    @State private var entranceScale: CGFloat = 0.8
    @State private var entranceBlur: CGFloat = 12
    @State private var entranceOpacity: Double = 0
    @State private var countdownPulse: CGFloat = 1.0
    @State private var lastSecond: Int = -1

    private var formattedSuggestedTime: String {
        let minutes = timer.suggestedDuration / 60
        let seconds = timer.suggestedDuration % 60
        if seconds == 0 {
            return "\(minutes):00"
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        if timer.shouldShowFor(exerciseId: exerciseId) {
            Group {
                if timer.isOfferingRestFor(exerciseId: exerciseId) {
                    restOptionButton
                } else if timer.isComplete {
                    completedState
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else if timer.isActiveFor(exerciseId: exerciseId) {
                    activeTimerState
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )
            .scaleEffect(entranceScale)
            .blur(radius: entranceBlur)
            .opacity(entranceOpacity)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: timer.isActive)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: timer.isComplete)
            .onChange(of: timer.isComplete) { _, complete in
                if !complete { completeBounceTrigger = false }
            }
            .onChange(of: timer.remainingSeconds) { oldValue, newValue in
                // Pulse on each second during active countdown
                if timer.isActive && newValue != lastSecond {
                    lastSecond = newValue
                    triggerCountdownPulse()
                }
            }
            .onAppear {
                // Entrance animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    entranceScale = 1.0
                    entranceBlur = 0
                    entranceOpacity = 1.0
                }
            }
            .onDisappear {
                // Reset for next appearance
                entranceScale = 0.8
                entranceBlur = 12
                entranceOpacity = 0
            }
        }
    }

    private func triggerCountdownPulse() {
        // Subtle pulse - more intense as time runs low
        let intensity: CGFloat = timer.remainingSeconds <= 5 ? 1.08 : 1.03
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            countdownPulse = intensity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                countdownPulse = 1.0
            }
        }
    }

    // "Rest ▸ 1:30" with per-exercise duration adjustment
    private var restOptionButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    timer.start()
                } label: {
                    HStack(spacing: 6) {
                        Text("Rest")
                            .font(.system(.subheadline, weight: .medium))
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(formattedSuggestedTime)
                            .font(.system(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Button { timer.adjustSuggestedDuration(delta: -30) } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(.subheadline))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 0) {
                        Button { timer.adjustSuggestedDuration(delta: -15) } label: {
                            Text("−")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(minWidth: 24)
                        }
                        .buttonStyle(.plain)
                        Text("15")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Button { timer.adjustSuggestedDuration(delta: 15) } label: {
                            Text("+")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(minWidth: 24)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    Button { timer.adjustSuggestedDuration(delta: 30) } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(.subheadline))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button { timer.dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Presets: 0:30, 1:00, 1:30, 2:00, 2:30, 3:00
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([30, 60, 90, 120, 150, 180], id: \.self) { secs in
                        let sel = timer.suggestedDuration == secs
                        Button {
                            timer.setSuggestedDuration(secs)
                        } label: {
                            Text(formatPreset(secs))
                                .font(.system(.caption, weight: sel ? .semibold : .regular))
                                .foregroundStyle(sel ? .primary : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(sel ? Color.secondary.opacity(0.2) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func formatPreset(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if s == 0 { return "\(m):00" }
        return String(format: "%d:%02d", m, s)
    }

    // Active countdown timer
    private var activeTimerState: some View {
        HStack(spacing: 16) {
            Text(timer.formattedTime)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(timer.remainingSeconds <= 5 ? .orange : .primary)
                .monospacedDigit()
                .frame(width: 50, alignment: .leading)
                .scaleEffect(countdownPulse)
                .contentTransition(.numericText(value: Double(timer.remainingSeconds)))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: timer.remainingSeconds)

            progressBar

            Button {
                timer.addSeconds(30)
            } label: {
                Text("+0:30")
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                timer.skip()
            } label: {
                Text("Skip")
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var progressBar: some View {
        // Using the animated liquid wave bar for a more organic feel
        LiquidWaveBar(progress: timer.progress)
            .animation(.linear(duration: 1.0), value: timer.progress)
    }

    private var completedState: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.green.opacity(0.8))
                .symbolEffect(.bounce, value: completeBounceTrigger)

            Text("Rest complete")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .onAppear {
            completeBounceTrigger = true
        }
    }
}

// MARK: - PR Celebration View
struct PRCelebrationView: View {
    @State private var bounceTrigger = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: bounceTrigger)

            Text("NEW PR!")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.primary)

            Text("Personal Record")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
        )
        .onAppear {
            bounceTrigger = true
        }
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
