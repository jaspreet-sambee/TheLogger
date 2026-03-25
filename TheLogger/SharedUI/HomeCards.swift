//
//  HomeCards.swift
//  TheLogger
//
//  Home screen card components and decorative effects
//

import SwiftUI

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
                            .fill(AppColors.accent)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
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
        case 1: return (AppColors.accent.opacity(0.35), AppColors.accent.opacity(0.18))
        case 2: return (AppColors.accent.opacity(0.55), AppColors.accent.opacity(0.32))
        case 3: return (AppColors.accent.opacity(0.75), AppColors.accent.opacity(0.45))
        case 4: return (AppColors.accent, AppColors.accent.opacity(0.6))
        case 5: return (Color(red: 1.0, green: 0.54, blue: 0.34), AppColors.accent)
        case 6: return (AppColors.accentGold.opacity(0.85), Color(red: 1.0, green: 0.54, blue: 0.34))
        case 7: return (AppColors.accentGold, AppColors.accentGold.opacity(0.65))
        default: return (Color(red: 1.0, green: 0.87, blue: 0.22), AppColors.accentGold)
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
                                .fill(AppColors.background)
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
        case 1: return AppColors.accent.opacity(0.35)
        case 2: return AppColors.accent.opacity(0.55)
        case 3: return AppColors.accent.opacity(0.75)
        case 4: return AppColors.accent
        case 5: return Color(red: 1.0, green: 0.54, blue: 0.34)
        case 6: return AppColors.accentGold.opacity(0.85)
        case 7: return AppColors.accentGold
        default: return Color(red: 1.0, green: 0.87, blue: 0.22)
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
        Text(message.text)
            .font(.system(.subheadline, weight: .regular))
            .foregroundStyle(.secondary)
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

// MARK: - Shimmer Effect

/// A shimmer sweep overlay using TimelineView for reliable infinite looping
struct ShimmerEffect: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            TimelineView(.animation(minimumInterval: 1/30)) { timeline in
                GeometryReader { geo in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let width = geo.size.width
                    let shimmerWidth = width * 0.5
                    let period = 4.0  // 3s sweep + 1s pause
                    let t = now.truncatingRemainder(dividingBy: period)
                    let progress = min(t / 3.0, 1.0)
                    let offset = progress * (width + shimmerWidth) - shimmerWidth

                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerWidth)
                    .offset(x: offset)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func shimmerEffect() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Animated Gradient Border

/// A RoundedRectangle border with a smoothly rotating angular gradient
struct AnimatedGradientBorder: View {
    let cornerRadius: CGFloat
    let colors: [Color]
    let lineWidth: CGFloat

    init(cornerRadius: CGFloat = 12, colors: [Color] = [AppColors.accent, AppColors.accentGold, AppColors.accent], lineWidth: CGFloat = 1.5) {
        self.cornerRadius = cornerRadius
        self.colors = colors
        self.lineWidth = lineWidth
    }

    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                AngularGradient(
                    colors: colors,
                    center: .center,
                    startAngle: .degrees(rotation),
                    endAngle: .degrees(rotation + 360)
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Floating Particles

/// Subtle drifting background particles rendered via Canvas
struct FloatingParticlesView: View {
    private let particleCount = 12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/15)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate

                for i in 0..<particleCount {
                    let seed = Double(i) * 7.31 + 1.9
                    let cycleX = 70.0 + Double(i % 3) * 20
                    let cycleY = 80.0 + Double(i % 4) * 15

                    let baseX = size.width * (sin(seed * 3.7) + 1) / 2
                    let baseY = size.height * (cos(seed * 2.3) + 1) / 2

                    let driftX = sin(now / cycleX * .pi * 2 + seed) * 50
                    let driftY = cos(now / cycleY * .pi * 2 + seed * 1.5) * 40

                    let x = baseX + driftX
                    let y = baseY + driftY
                    let radius = 2.0 + seed.truncatingRemainder(dividingBy: 4.0)

                    context.fill(
                        Circle().path(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(AppColors.accent.opacity(0.04))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
