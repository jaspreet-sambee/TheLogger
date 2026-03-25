//
//  DecorationViews.swift
//  TheLogger
//
//  Preview providers for animation components
//

import SwiftUI

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
