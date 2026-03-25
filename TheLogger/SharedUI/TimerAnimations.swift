//
//  TimerAnimations.swift
//  TheLogger
//
//  Timer and progress animation components
//

import SwiftUI

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
                    AppColors.accent.opacity(0.7),
                    Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.5)
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
                .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
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
                    AppColors.accent.opacity(0.7),
                    Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.6)
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
                .stroke(AppColors.accent.opacity(0.15), lineWidth: 6)

            // Progress ring - solid orange
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
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
