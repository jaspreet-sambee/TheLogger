//
//  StepperAnimations.swift
//  TheLogger
//
//  Haptic stepper and counting animation components
//

import SwiftUI

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
    @State private var minusButtonScale: CGFloat = 1.0
    @State private var plusButtonScale: CGFloat = 1.0
    @State private var numberScale: CGFloat = 1.0
    @State private var numberGlow: CGFloat = 0

    init(value: Binding<Double>, step: Double = 5.0, range: ClosedRange<Double> = 0...1000, unit: String = "lbs") {
        self._value = value
        self.step = step
        self.range = range
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: 16) {
            // Decrease button with individual pulse
            Button {
                adjustValue(by: -step)
                triggerMinusButtonPulse()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .scaleEffect(minusButtonScale)

            // Value display with multiple visual effects
            VStack(spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: value))
                    .scaleEffect(numberScale)
                    .shadow(color: AppColors.accent.opacity(numberGlow), radius: 12)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: numberScale)
                    .animation(.linear(duration: 0.15), value: numberGlow)
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
                            let oldValue = value
                            value = roundedValue
                            triggerNumberFlash()
                            triggerWeightChangeHaptic(from: oldValue, to: roundedValue)
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

            // Increase button with individual pulse
            Button {
                adjustValue(by: step)
                triggerPlusButtonPulse()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.accent)
            }
            .buttonStyle(.plain)
            .scaleEffect(plusButtonScale)
        }
        .padding(.vertical, 8)
    }

    private func adjustValue(by delta: Double) {
        let oldValue = value
        let newValue = value + delta
        let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
        value = clampedValue
        triggerNumberFlash()
        triggerWeightChangeHaptic(from: oldValue, to: clampedValue)
    }

    private func triggerMinusButtonPulse() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            minusButtonScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                minusButtonScale = 1.0
            }
        }
    }

    private func triggerPlusButtonPulse() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            plusButtonScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                plusButtonScale = 1.0
            }
        }
    }

    private func triggerNumberFlash() {
        // Scale up briefly
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            numberScale = 1.15
        }
        // Glow flash
        withAnimation(.linear(duration: 0.1)) {
            numberGlow = 0.6
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                numberScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3)) {
                numberGlow = 0
            }
        }
    }

    private func triggerWeightChangeHaptic(from oldValue: Double, to newValue: Double) {
        // Check for milestone (every 25 lbs)
        let isMilestone = Int(newValue) % 25 == 0 && Int(oldValue) % 25 != 0

        if isMilestone {
            // Stronger haptic for milestones
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        } else {
            // Normal light haptic
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
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
                    .foregroundStyle(AppColors.accent)
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
            .contentTransition(.numericText(value: Double(displayValue)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayValue)
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
