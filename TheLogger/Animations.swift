//
//  Animations.swift
//  TheLogger
//
//  Premium animation components for enhanced UX
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

    init(progress: Double, lineWidth: CGFloat = 8, gradientColors: [Color] = [.blue, .teal]) {
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
                    gradientColors.first?.opacity(glowOpacity) ?? Color.blue.opacity(glowOpacity),
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
                    .foregroundStyle(gradientColors.first ?? .blue)
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
                .fill(isComplete ? Color.blue : Color.secondary.opacity(0.2))
                .frame(width: 24, height: 24)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .opacity(pulse ? 0.5 : 1.0)

            if isComplete {
                Circle()
                    .fill(Color.blue)
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

// MARK: - Liquid Wave Timer View

/// An organic "liquid fill" timer that drains as time passes
struct LiquidWaveTimer: View {
    let progress: Double // 0.0 (empty) to 1.0 (full)
    let isComplete: Bool

    @State private var phase: Double = 0

    private let waveHeight: CGFloat = 8
    private let waveFrequency: Double = 2.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                // Update phase based on time
                let now = timeline.date.timeIntervalSinceReferenceDate
                let currentPhase = now.truncatingRemainder(dividingBy: 2) * .pi

                // Calculate water level (inverted progress - drains down)
                let waterLevel = size.height * (1 - progress)

                // Create wave path
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))

                // Bottom left
                path.addLine(to: CGPoint(x: 0, y: waterLevel))

                // Wave across the top
                for x in stride(from: 0, through: size.width, by: 2) {
                    let relativeX = x / size.width
                    let sine = sin(currentPhase + relativeX * .pi * waveFrequency)
                    let y = waterLevel + sine * waveHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                // Close the path
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()

                // Draw gradient fill
                let gradient = Gradient(colors: [
                    Color.blue.opacity(0.7),
                    Color.teal.opacity(0.5)
                ])

                context.fill(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: waterLevel),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // Add subtle highlight on wave crests
                var highlightPath = Path()
                highlightPath.move(to: CGPoint(x: 0, y: waterLevel))
                for x in stride(from: 0, through: size.width, by: 2) {
                    let relativeX = x / size.width
                    let sine = sin(currentPhase + relativeX * .pi * waveFrequency)
                    let y = waterLevel + sine * waveHeight
                    highlightPath.addLine(to: CGPoint(x: x, y: y))
                }

                context.stroke(
                    highlightPath,
                    with: .color(.white.opacity(0.3)),
                    lineWidth: 2
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Compact Liquid Timer (for inline use)

/// A horizontal liquid wave bar for the rest timer
struct LiquidWaveBar: View {
    let progress: Double // 0.0 to 1.0 (how much time has passed)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/24)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let phase = now.truncatingRemainder(dividingBy: 3) * .pi * 2 / 3

                // The filled portion width
                let fillWidth = size.width * progress

                // Create wave path
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: 0))

                // Smooth wave at the leading edge
                let waveWidth: CGFloat = 20
                let waveHeight: CGFloat = size.height * 0.3

                for x in stride(from: 0, through: fillWidth, by: 1) {
                    // Wave effect near the edge
                    let distanceFromEdge = fillWidth - x
                    let waveInfluence = min(1, distanceFromEdge / waveWidth)
                    let sine = sin(phase + x * 0.15) * waveHeight * (1 - waveInfluence)
                    let y = size.height / 2 + sine

                    if x == 0 {
                        path.move(to: CGPoint(x: 0, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                // Create the filled shape
                var fillPath = Path()
                fillPath.move(to: CGPoint(x: 0, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: 0))
                fillPath.addLine(to: CGPoint(x: fillWidth, y: 0))
                fillPath.addLine(to: CGPoint(x: fillWidth, y: size.height))
                fillPath.closeSubpath()

                // Draw base fill
                let gradient = Gradient(colors: [
                    Color.blue.opacity(0.7),
                    Color.teal.opacity(0.6)
                ])

                context.fill(
                    fillPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    )
                )

                // Add shimmer effect
                let shimmerX = (now.truncatingRemainder(dividingBy: 2) / 2) * size.width
                let shimmerGradient = Gradient(colors: [
                    .clear,
                    .white.opacity(0.2),
                    .clear
                ])

                var shimmerRect = Path()
                shimmerRect.addRect(CGRect(x: shimmerX - 30, y: 0, width: 60, height: size.height))

                context.clip(to: fillPath)
                context.fill(
                    shimmerRect,
                    with: .linearGradient(
                        shimmerGradient,
                        startPoint: CGPoint(x: shimmerX - 30, y: 0),
                        endPoint: CGPoint(x: shimmerX + 30, y: 0)
                    )
                )
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.15))
        )
    }
}

// MARK: - Workout Progress Ring

/// A ring showing overall workout progress (sets completed / total sets)
struct WorkoutProgressRing: View {
    let completedSets: Int
    let totalSets: Int

    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return min(1.0, Double(completedSets) / Double(totalSets))
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 6)

            // Progress ring - solid blue
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)

            VStack(spacing: 2) {
                Text("\(completedSets)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("sets")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
    }
}

// MARK: - Haptic Weight Stepper

/// A stepper with haptic feedback for weight adjustments
/// The center value is scaled larger, providing visual focus
struct HapticWeightStepper: View {
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String

    @State private var isDragging: Bool = false
    @State private var lastHapticValue: Double = 0

    init(value: Binding<Double>, step: Double = 5.0, range: ClosedRange<Double> = 0...1000, unit: String = "lbs") {
        self._value = value
        self.step = step
        self.range = range
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: 16) {
            // Decrease button
            Button {
                adjustValue(by: -step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Value display with scale effect
            VStack(spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)

                Text(unit)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 80)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        // Vertical drag changes value
                        let dragStep = -gesture.translation.height / 20
                        let newValue = lastHapticValue + dragStep * step
                        let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)

                        // Round to step
                        let roundedValue = (clampedValue / step).rounded() * step

                        if roundedValue != value {
                            value = roundedValue
                            // Haptic on each step
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastHapticValue = value
                    }
            )
            .onAppear {
                lastHapticValue = value
            }

            // Increase button
            Button {
                adjustValue(by: step)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private func adjustValue(by delta: Double) {
        let newValue = value + delta
        let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
        value = clampedValue

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Haptic Reps Stepper

/// A compact stepper for reps with haptic feedback
struct HapticRepsStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(value: Binding<Int>, range: ClosedRange<Int> = 1...100) {
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                adjustValue(by: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(minWidth: 50)

            Button {
                adjustValue(by: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private func adjustValue(by delta: Int) {
        let newValue = value + delta
        guard range.contains(newValue) else { return }
        value = newValue

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Counting Number Animation

/// Animates a number counting up from 0 to target value
struct CountingNumber: View {
    let value: Int
    let duration: Double
    @State private var displayValue: Int = 0

    init(value: Int, duration: Double = 0.8) {
        self.value = value
        self.duration = duration
    }

    var body: some View {
        Text("\(displayValue)")
            .onAppear {
                animateValue()
            }
            .onChange(of: value) { _, _ in
                animateValue()
            }
    }

    private func animateValue() {
        guard value > 0 else {
            displayValue = 0
            return
        }
        let steps = min(value, 20)
        guard steps > 0 else {
            displayValue = value
            return
        }
        let stepDuration = duration / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeOut(duration: 0.1)) {
                    displayValue = (value * i) / steps
                }
            }
        }
    }
}

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

    init(color: Color = .orange) {
        self.color = color
    }

    var body: some View {
        Image(systemName: "flame.fill")
            .foregroundStyle(color)
            .symbolEffect(.bounce, value: isAnimating)
            .onAppear {
                // Bounce every 2.5 seconds
                Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                    isAnimating.toggle()
                }
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
        .frame(maxWidth: .infinity)
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

/// Adds a staggered fade-in and slide-up animation based on index
struct StaggeredAppear: ViewModifier {
    let index: Int
    let maxStagger: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .onAppear {
                let delay = Double(min(index, maxStagger)) * 0.08
                withAnimation(.easeOut(duration: 0.3).delay(delay)) {
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
    func glassMorphism(cornerRadius: CGFloat = 16, intensity: Double = 0.8) -> some View {
        modifier(GlassMorphism(cornerRadius: cornerRadius, intensity: intensity))
    }
}

// MARK: - Recent Workout Card (for horizontal scroll)

/// A compact card for displaying recent workouts in a horizontal scroll
struct RecentWorkoutCard: View {
    let workout: Workout
    let onTap: () -> Void

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.date) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            return formatter.string(from: workout.date)
        }
    }

    private var duration: String? {
        guard let start = workout.startTime, let end = workout.endTime else { return nil }
        let minutes = Int(end.timeIntervalSince(start)) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Date badge
                Text(formattedDate)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )

                // Workout name
                Text(workout.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Stats row
                HStack(spacing: 12) {
                    Label("\(workout.exerciseCount)", systemImage: "figure.strengthtraining.traditional")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let dur = duration {
                        Label(dur, systemImage: "clock")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(width: 140, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemGray6),
                                Color(.systemGray5).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weekly Goal Ring

/// A circular progress ring showing weekly workout goal progress
struct WeeklyGoalRing: View {
    let current: Int
    let goal: Int
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.6)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text("\(current)/\(goal)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("this week")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Level Avatar

/// User avatar with level-based gradient colors that evolve with fitness progress
struct LevelAvatar: View {
    let name: String
    let totalWorkouts: Int
    var size: CGFloat = 48

    private var level: Int {
        switch totalWorkouts {
        case 0..<5: return 1
        case 5..<15: return 2
        case 15..<30: return 3
        case 30..<50: return 4
        case 50..<100: return 5
        case 100..<200: return 6
        case 200..<500: return 7
        default: return 8
        }
    }

    private var levelColors: (primary: Color, secondary: Color) {
        switch level {
        case 1: return (.gray, .gray.opacity(0.6))              // Rookie
        case 2: return (.green, .mint)                           // Regular
        case 3: return (.blue, .cyan)                            // Dedicated
        case 4: return (.purple, .indigo)                        // Strong
        case 5: return (.orange, .yellow)                        // Elite
        case 6: return (.red, .orange)                           // Champion
        case 7: return (.yellow, .orange)                        // Legend
        default: return (.pink, .purple)                         // Master
        }
    }

    private var initial: String {
        String(name.prefix(1).uppercased())
    }

    var body: some View {
        ZStack {
            // Gradient background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [levelColors.primary, levelColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Subtle inner shadow for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.15)],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            // Ring highlight at top
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size - 2, height: size - 2)

            // Initial letter
            if name.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Level indicator dot (shows level number for levels > 1)
            if level > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: size * 0.38, height: size * 0.38)
                            Circle()
                                .fill(levelColors.primary)
                                .frame(width: size * 0.32, height: size * 0.32)
                            Text("\(level)")
                                .font(.system(size: size * 0.18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: size * 0.08, y: size * 0.08)
                    }
                }
                .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Level Badge

/// Shows user's fitness level based on total workouts
struct LevelBadge: View {
    let totalWorkouts: Int

    private var level: Int {
        switch totalWorkouts {
        case 0..<5: return 1
        case 5..<15: return 2
        case 15..<30: return 3
        case 30..<50: return 4
        case 50..<100: return 5
        case 100..<200: return 6
        case 200..<500: return 7
        default: return 8
        }
    }

    private var levelName: String {
        switch level {
        case 1: return "Rookie"
        case 2: return "Regular"
        case 3: return "Dedicated"
        case 4: return "Strong"
        case 5: return "Elite"
        case 6: return "Champion"
        case 7: return "Legend"
        default: return "Master"
        }
    }

    private var levelColor: Color {
        switch level {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return .orange
        case 6: return .red
        case 7: return .yellow
        default: return .pink
        }
    }

    private var workoutsToNextLevel: Int {
        let thresholds = [5, 15, 30, 50, 100, 200, 500, Int.max]
        let currentThreshold = thresholds[min(level - 1, thresholds.count - 1)]
        return max(0, currentThreshold - totalWorkouts)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Level icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [levelColor, levelColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text("Lv\(level)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(levelName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(levelColor)

                if workoutsToNextLevel > 0 && level < 8 {
                    Text("\(workoutsToNextLevel) more to level up")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(levelColor.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(levelColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Streak Confetti Particle

/// A single confetti particle for streak celebrations
struct StreakConfettiParticle: View {
    let color: Color
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    @State private var scale: Double = 1

    let startPosition: CGPoint
    let velocity: CGPoint

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                position = startPosition
                withAnimation(.linear(duration: 2)) {
                    position = CGPoint(
                        x: startPosition.x + velocity.x,
                        y: startPosition.y + velocity.y + 200
                    )
                    rotation = Double.random(in: 360...720)
                    opacity = 0
                    scale = 0.5
                }
            }
    }
}

// MARK: - Streak Confetti View

/// Displays a burst of confetti for streak celebrations
struct StreakConfettiView: View {
    let isActive: Bool
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    @State private var particles: [(id: UUID, color: Color, start: CGPoint, velocity: CGPoint)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    StreakConfettiParticle(
                        color: particle.color,
                        startPosition: particle.start,
                        velocity: particle.velocity
                    )
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    triggerConfetti(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func triggerConfetti(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 3)
        var newParticles: [(UUID, Color, CGPoint, CGPoint)] = []

        for _ in 0..<30 {
            let color = colors.randomElement() ?? .blue
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 100...200)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed - 100
            )
            newParticles.append((UUID(), color, center, velocity))
        }

        particles = newParticles

        // Clear after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            particles = []
        }
    }
}

// MARK: - Rest Day Encouragement

/// Shows encouraging messages on rest days
struct RestDayMessage: View {
    let daysSinceLastWorkout: Int

    private var message: (emoji: String, text: String) {
        switch daysSinceLastWorkout {
        case 1:
            return ("", "Rest day - recovery is part of progress")
        case 2:
            return ("", "Two days rest - muscles are rebuilding")
        case 3:
            return ("", "Ready to get back to it?")
        case 4...6:
            return ("", "Your body is rested and ready!")
        default:
            return ("", "Welcome back - let's crush it!")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(message.emoji)
                .font(.system(.title3))

            Text(message.text)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Depth Shadow Modifier

/// Adds layered shadows for depth effect
struct DepthShadow: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.1), radius: radius / 3, x: 0, y: radius / 6)
            .shadow(color: color.opacity(0.08), radius: radius / 2, x: 0, y: radius / 3)
            .shadow(color: color.opacity(0.05), radius: radius, x: 0, y: radius / 2)
    }
}

extension View {
    func depthShadow(color: Color = .black, radius: CGFloat = 12) -> some View {
        modifier(DepthShadow(color: color, radius: radius))
    }
}

// MARK: - Preview

#Preview("Ring Progress") {
    VStack(spacing: 40) {
        RingFillProgress(progress: 0.7, lineWidth: 10)
            .frame(width: 100, height: 100)

        WorkoutProgressRing(completedSets: 8, totalSets: 12)

        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { num in
                SetCompletionRing(setNumber: num, isComplete: num <= 3)
            }
        }
    }
    .padding()
    .background(Color.black)
}

#Preview("Liquid Wave") {
    VStack(spacing: 30) {
        LiquidWaveTimer(progress: 0.6, isComplete: false)
            .frame(height: 120)
            .padding()

        LiquidWaveBar(progress: 0.4)
            .padding()
    }
    .background(Color.black)
}

#Preview("Haptic Steppers") {
    struct PreviewWrapper: View {
        @State private var weight: Double = 135.0
        @State private var reps: Int = 10

        var body: some View {
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HapticWeightStepper(value: $weight)
                }

                VStack(spacing: 8) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HapticRepsStepper(value: $reps)
                }
            }
            .padding()
            .background(Color.black)
        }
    }
    return PreviewWrapper()
}
