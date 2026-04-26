//
//  RestDayChallengeView.swift
//  TheLogger
//
//  Rest day challenge views — Quiz, Quick Hit, Spin Wheel
//

import SwiftUI
import SwiftData

// MARK: - Challenge Picker (shown on Home screen card tap)

struct ChallengePicker: View {
    let canQuiz: Bool
    let workoutCount: Int  // total completed workouts, for "X more to go" label
    let onPickQuiz: () -> Void
    let onPickQuickHit: () -> Void
    let onPickSpin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Quiz — always shown, greyed out until 5 workouts
            Button {
                if canQuiz { onPickQuiz() }
            } label: {
                VStack(spacing: 6) {
                    Text("🧠")
                        .font(.system(size: 24))
                        .opacity(canQuiz ? 1.0 : 0.35)
                    Text("Quiz")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(canQuiz ? Color.white.opacity(0.75) : Color.white.opacity(0.25))
                    if canQuiz {
                        Text("5 Qs from your history")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.30))
                            .multilineTextAlignment(.center)
                        Text("~1 min")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.20))
                    } else {
                        Text("\(max(0, 5 - workoutCount)) more workouts to unlock")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.18))
                            .multilineTextAlignment(.center)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.15))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(canQuiz ? 0.04 : 0.02))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(canQuiz ? 0.08 : 0.05), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canQuiz)

            challengeOption(icon: "💪", name: "Quick Hit", desc: "Bodyweight challenge", time: "~3 min") {
                onPickQuickHit()
            }
            challengeOption(icon: "🎰", name: "Spin", desc: "Random challenge", time: "???") {
                onPickSpin()
            }
        }
    }

    private func challengeOption(icon: String, name: String, desc: String, time: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 24))
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .multilineTextAlignment(.center)
                Text(time)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.20))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quiz View

struct QuizChallengeView: View {
    @Binding var challenge: DailyChallenge
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAnswer: Int? = nil
    @State private var showResult = false
    @State private var currentQuestionIndex = 0

    private var questions: [QuizQuestion] {
        challenge.quizQuestions ?? []
    }

    private var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<questions.count, id: \.self) { i in
                        Circle()
                            .fill(dotColor(for: i))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.vertical, 12)

                if let q = currentQuestion {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Question
                            Text(q.question)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            // Options
                            VStack(spacing: 10) {
                                ForEach(Array(q.options.enumerated()), id: \.offset) { index, option in
                                    Button {
                                        answerQuestion(index)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(["A", "B", "C", "D"][index])
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(optionLetterColor(index, question: q))
                                                .frame(width: 28, height: 28)
                                                .background(Circle().fill(optionLetterBg(index, question: q)))
                                            Text(option)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(optionTextColor(index, question: q))
                                            Spacer()
                                            if showResult && index == q.correctIndex {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.green)
                                            } else if showResult && index == selectedAnswer && index != q.correctIndex {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(optionBg(index, question: q))
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(optionBorder(index, question: q), lineWidth: 1))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(showResult)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else {
                    // Quiz complete
                    quizCompleteView
                }

                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle("Know Your Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func answerQuestion(_ index: Int) {
        selectedAnswer = index
        showResult = true
        challenge.quizAnswered += 1
        if index == currentQuestion?.correctIndex {
            challenge.quizScore += 1
        }
        challenge.save()

        // Auto-advance after 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentQuestionIndex += 1
                selectedAnswer = nil
                showResult = false

                if currentQuestionIndex >= questions.count {
                    challenge.isCompleted = true
                    challenge.save()
                }
            }
        }
    }

    private var quizCompleteView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🎉")
                .font(.system(size: 48))
            Text("\(challenge.quizScore)/\(questions.count) Correct")
                .font(.system(size: 28, weight: .heavy))
            Text("Streak saved! +30 XP")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.accentGold)
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Styling Helpers

    private func dotColor(for index: Int) -> Color {
        if index < currentQuestionIndex {
            // Already answered
            if let q = questions[safe: index] {
                // We don't track per-question correctness in the model, simplify
                return index < challenge.quizScore ? .green : .red
            }
            return .gray
        } else if index == currentQuestionIndex {
            return Color(red: 0.50, green: 0.65, blue: 1.0) // blue
        }
        return Color.white.opacity(0.12)
    }

    private func optionBg(_ index: Int, question: QuizQuestion) -> Color {
        guard showResult else { return Color.white.opacity(0.05) }
        if index == question.correctIndex { return Color.green.opacity(0.12) }
        if index == selectedAnswer { return Color.red.opacity(0.10) }
        return Color.white.opacity(0.05)
    }

    private func optionBorder(_ index: Int, question: QuizQuestion) -> Color {
        guard showResult else { return Color.white.opacity(0.10) }
        if index == question.correctIndex { return Color.green.opacity(0.35) }
        if index == selectedAnswer { return Color.red.opacity(0.30) }
        return Color.white.opacity(0.10)
    }

    private func optionTextColor(_ index: Int, question: QuizQuestion) -> Color {
        guard showResult else { return Color.white.opacity(0.70) }
        if index == question.correctIndex { return .green }
        if index == selectedAnswer { return .red }
        return Color.white.opacity(0.40)
    }

    private func optionLetterColor(_ index: Int, question: QuizQuestion) -> Color {
        guard showResult else { return Color.white.opacity(0.45) }
        if index == question.correctIndex { return .green }
        return Color.white.opacity(0.30)
    }

    private func optionLetterBg(_ index: Int, question: QuizQuestion) -> Color {
        guard showResult else { return Color.white.opacity(0.08) }
        if index == question.correctIndex { return Color.green.opacity(0.25) }
        return Color.white.opacity(0.08)
    }
}

// MARK: - Quick Hit View

struct QuickHitChallengeView: View {
    @Binding var challenge: DailyChallenge
    @Environment(\.dismiss) private var dismiss

    private var exercise: QuickHitExercise {
        challenge.quickHitExercise ?? .pushups
    }

    private var target: Int {
        challenge.quickHitTarget ?? 40
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(challenge.quickHitProgress) / Double(target))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Exercise icon + name
                Text(exercise.icon)
                    .font(.system(size: 48))
                Text(exercise.rawValue)
                    .font(.system(size: 24, weight: .heavy))
                Text(exercise.isTimeBased ? "Target: \(target) seconds" : "Target: \(target) reps")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.40))

                // Counter
                HStack(spacing: 20) {
                    Button {
                        if challenge.quickHitProgress > 0 {
                            challenge.quickHitProgress -= (exercise.isTimeBased ? 5 : 1)
                            challenge.save()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Text("−")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(Color.red.opacity(0.7))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Color.red.opacity(0.12)).overlay(Circle().stroke(Color.red.opacity(0.25), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)

                    Text("\(challenge.quickHitProgress)")
                        .font(.system(size: 56, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(challenge.quickHitProgress >= target ? .green : AppColors.accent)
                        .frame(minWidth: 100)

                    Button {
                        challenge.quickHitProgress += (exercise.isTimeBased ? 5 : 1)
                        challenge.save()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if challenge.quickHitProgress >= target && !challenge.isCompleted {
                            challenge.isCompleted = true
                            challenge.save()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Text("+")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(AppColors.accent.opacity(0.8))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(AppColors.accent.opacity(0.12)).overlay(Circle().stroke(AppColors.accent.opacity(0.25), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }

                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 100)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 100)
                                .fill(
                                    challenge.isCompleted
                                    ? LinearGradient(colors: [.green, Color(red: 0.13, green: 0.63, blue: 0.25)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [AppColors.accent, Color(red: 1.0, green: 0.35, blue: 0.19)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)

                    Text(challenge.isCompleted
                         ? "✓ Complete!"
                         : "\(challenge.quickHitProgress) of \(target) — \(target - challenge.quickHitProgress) more")
                        .font(.system(size: 12))
                        .foregroundStyle(challenge.isCompleted ? Color.green : Color.white.opacity(0.35))
                }
                .padding(.horizontal, 40)

                // Tip
                if !challenge.isCompleted {
                    HStack(alignment: .top, spacing: 8) {
                        Text("💡")
                            .font(.system(size: 14))
                        Text(exercise.isTimeBased
                             ? "Hold the position. Tap + to add 5 seconds at a time."
                             : "Break it into sets — do 10 at a time. Tap + after each mini-set.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accentGold.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accentGold.opacity(0.15), lineWidth: 1))
                    )
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Done button
                Button { dismiss() } label: {
                    Text(challenge.isCompleted ? "🔥 Streak Saved!" : "Done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(challenge.isCompleted ? Color.green : Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .navigationTitle("Quick Hit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Spin Wheel View

// MARK: - Triangle Shape (for wheel pointer)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Spin Wheel

struct SpinWheelView: View {
    let canQuiz: Bool
    let workouts: [Workout]
    let prs: [PersonalRecord]
    let onResult: (DailyChallenge) -> Void
    @Environment(\.dismiss) private var dismiss

    private let segments: [(icon: String, label: String)] = [
        ("🫸", "Pushups"),
        ("🧠", "Quiz"),
        ("🦵", "Squats"),
        ("🧘", "Plank"),
        ("💪", "Burpees"),
        ("🚶", "Lunges"),
    ]

    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var resultIndex: Int? = nil
    @State private var showResult = false

    private let gold = Color(red: 0.94, green: 0.72, blue: 0.20)
    private let segmentColors: [Color] = [
        Color(red: 0.91, green: 0.22, blue: 0.29),  // red
        Color(red: 0.50, green: 0.65, blue: 1.0),    // blue
        Color(red: 1.0,  green: 0.72, blue: 0.30),   // gold
        Color(red: 0.20, green: 0.82, blue: 0.35),   // green
        Color(red: 0.91, green: 0.22, blue: 0.29),   // red
        Color(red: 0.50, green: 0.65, blue: 1.0),    // blue
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 4) {
                    Text("Rest Day Challenge")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(showResult ? "You got..." : "Spin to pick today's mini challenge")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .padding(.top, 16)

                Spacer()

                // Wheel area
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gold.opacity(0.12), .clear],
                                center: .center,
                                startRadius: 100,
                                endRadius: 180
                            )
                        )
                        .frame(width: 340, height: 340)

                    // Outer decorative ring
                    Circle()
                        .stroke(gold.opacity(0.20), lineWidth: 3)
                        .frame(width: 280, height: 280)
                        .shadow(color: gold.opacity(0.08), radius: 15)

                    // Tick marks
                    ForEach(0..<24, id: \.self) { i in
                        Rectangle()
                            .fill(gold.opacity(0.30))
                            .frame(width: 2, height: 8)
                            .offset(y: -140)
                            .rotationEffect(.degrees(Double(i) * 15))
                    }

                    // Spinning disc
                    ZStack {
                        // Segment fills
                        ForEach(0..<segments.count, id: \.self) { i in
                            wheelSegment(index: i)
                        }

                        // Divider lines
                        ForEach(0..<segments.count, id: \.self) { i in
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1, height: 134)
                                .offset(y: -67)
                                .rotationEffect(.degrees(Double(i) * 60))
                        }

                        // Segment icons
                        ForEach(0..<segments.count, id: \.self) { i in
                            let angle = Double(i) * 60 + 30
                            Text(segments[i].icon)
                                .font(.system(size: 26))
                                .offset(y: -95)
                                .rotationEffect(.degrees(angle))
                        }
                    }
                    .frame(width: 268, height: 268)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(rotation))

                    // Center hub
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.12, green: 0.12, blue: 0.15), AppColors.background],
                                center: UnitPoint(x: 0.4, y: 0.35),
                                startRadius: 0,
                                endRadius: 36
                            )
                        )
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(gold.opacity(0.30), lineWidth: 2))
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.10), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 64, height: 64)
                        )
                        .overlay(
                            VStack(spacing: 1) {
                                if showResult {
                                    Text("🎉")
                                        .font(.system(size: 22))
                                } else {
                                    Text("SPIN")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundStyle(gold)
                                        .tracking(1)
                                }
                            }
                        )
                        .shadow(color: gold.opacity(0.12), radius: 10)

                    // Pointer triangle at top
                    Triangle()
                        .fill(gold)
                        .frame(width: 24, height: 18)
                        .shadow(color: gold.opacity(0.5), radius: 6, y: 2)
                        .offset(y: -148)
                }
                .scaleEffect(showResult ? 0.82 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showResult)

                Spacer()

                // Result card
                if showResult, let idx = resultIndex {
                    VStack(spacing: 8) {
                        Text(segments[idx].icon)
                            .font(.system(size: 38))
                        Text(segments[idx].label + "!")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("Complete to keep your streak alive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(gold.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.20), lineWidth: 1))
                    )
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))

                    Button(action: generateAndLaunch) {
                        HStack(spacing: 8) {
                            Text("💪")
                            Text("Let's Go!")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundStyle(Color(red: 0.10, green: 0.06, blue: 0.0))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [Color(red: 0.94, green: 0.72, blue: 0.20), Color(red: 0.83, green: 0.53, blue: 0.12)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(red: 0.83, green: 0.53, blue: 0.12).opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                }

                // Spin button (before spin)
                if !isSpinning && !showResult {
                    Spacer()
                    Button(action: spin) {
                        HStack(spacing: 8) {
                            Text("🎰")
                            Text("Spin!")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundStyle(Color(red: 0.10, green: 0.06, blue: 0.0))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [Color(red: 0.94, green: 0.72, blue: 0.20), Color(red: 0.83, green: 0.53, blue: 0.12)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(red: 0.83, green: 0.53, blue: 0.12).opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Spin the Wheel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func wheelSegment(index: Int) -> some View {
        let total = segments.count
        let color = segmentColors[index % segmentColors.count]
        return Circle()
            .trim(from: Double(index) / Double(total), to: Double(index + 1) / Double(total))
            .stroke(color.opacity(0.28), lineWidth: 60)
            .frame(width: 208, height: 208)
            .rotationEffect(.degrees(-90))
    }

    private func spin() {
        isSpinning = true
        showResult = false

        // Pick which segment to land on
        let availableSegments = canQuiz ? segments.indices.map { $0 } : segments.indices.filter { segments[$0].label != "Quiz" }
        let targetIdx = availableSegments.randomElement() ?? 0
        resultIndex = targetIdx

        // Calculate rotation to land on target segment
        let segmentAngle = 360.0 / Double(segments.count)
        let targetAngle = Double(targetIdx) * segmentAngle + segmentAngle / 2
        // Spin 5 full rotations + land on target (pointer is at top, so subtract targetAngle)
        let finalRotation = rotation + 1800 + (360 - targetAngle)

        withAnimation(.easeOut(duration: 3.0)) {
            rotation = finalRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            isSpinning = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showResult = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func generateAndLaunch() {
        guard let idx = resultIndex else { return }
        let label = segments[idx].label

        if label == "Quiz", let quiz = ChallengeGenerator.generateQuiz(workouts: workouts, prs: prs) {
            onResult(quiz)
        } else {
            // Map label to QuickHitExercise
            let exercise: QuickHitExercise
            switch label {
            case "Pushups": exercise = .pushups
            case "Squats": exercise = .squats
            case "Plank": exercise = .plank
            case "Burpees": exercise = .burpees
            case "Lunges": exercise = .lunges
            default: exercise = .pushups
            }
            var challenge = DailyChallenge(
                id: {
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
                }(),
                date: Date(),
                category: .quickHit,
                quickHitExercise: exercise,
                quickHitTarget: exercise.baseTarget
            )
            onResult(challenge)
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
