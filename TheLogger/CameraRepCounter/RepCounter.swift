//
//  RepCounter.swift
//  TheLogger
//
//  State machine for counting exercise repetitions based on joint angles
//

import Foundation
import UIKit

/// Counts repetitions by tracking joint angle transitions
@Observable
final class RepCounter {

    // MARK: - Types

    /// The current phase of the repetition
    enum Phase: String {
        case up = "UP"      // Extended/standing position
        case down = "DOWN"  // Flexed/bottom position
    }

    /// Feedback for the current movement state
    enum MovementFeedback: String {
        case ready = "Ready"
        case goingDown = "Going down..."
        case holdingDown = "At bottom"
        case goingUp = "Coming up..."
        case repComplete = "Rep!"
        case noDetection = "Position yourself in frame"
    }

    // MARK: - Properties

    /// Current rep count
    private(set) var repCount: Int = 0

    /// Current movement phase
    private(set) var currentPhase: Phase = .up

    /// Current feedback message
    private(set) var feedback: MovementFeedback = .ready

    /// Current detected angle (for debugging/display)
    private(set) var currentAngle: Double = 0

    /// Whether detection is currently active
    var isActive: Bool = true

    /// The exercise configuration being tracked
    private let exerciseType: ExerciseType
    private let configuration: JointConfiguration

    /// Smoothing for angle readings (reduces noise)
    private var angleHistory: [Double] = []
    private let smoothingWindow = 5

    /// Debouncing to prevent double-counting
    private var lastRepTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.4  // Minimum time between reps

    /// Haptic feedback generator
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Initialization

    init(exerciseType: ExerciseType) {
        self.exerciseType = exerciseType
        self.configuration = exerciseType.jointConfiguration
        hapticGenerator.prepare()
    }

    // MARK: - Public Methods

    /// Process a new angle reading and detect reps
    /// - Parameter angle: The current joint angle in degrees
    /// - Returns: True if a rep was just completed
    @discardableResult
    func processAngle(_ angle: Double) -> Bool {
        guard isActive else { return false }

        // Add to history for smoothing
        angleHistory.append(angle)
        if angleHistory.count > smoothingWindow {
            angleHistory.removeFirst()
        }

        // Calculate smoothed angle
        let smoothedAngle = angleHistory.reduce(0, +) / Double(angleHistory.count)
        currentAngle = smoothedAngle

        // Detect phase transitions
        return detectRep(angle: smoothedAngle)
    }

    /// Reset the counter
    func reset() {
        repCount = 0
        currentPhase = .up
        feedback = .ready
        angleHistory.removeAll()
    }

    /// Manually add a rep (for testing or manual override)
    func addRep() {
        repCount += 1
        triggerHaptic()
    }

    // MARK: - Private Methods

    private func detectRep(angle: Double) -> Bool {
        let downThreshold = configuration.downThreshold
        let upThreshold = configuration.upThreshold

        // Handle exercises where "down" means smaller angle (like bicep curl)
        let isInvertedExercise = downThreshold < upThreshold

        switch currentPhase {
        case .up:
            // Looking for user to go DOWN
            if isInvertedExercise {
                // Angle decreases when going down (e.g., bicep curl)
                if angle < downThreshold {
                    currentPhase = .down
                    feedback = .holdingDown
                } else if angle < (upThreshold - 20) {
                    feedback = .goingDown
                }
            } else {
                // Angle decreases when going down (e.g., squat)
                if angle < downThreshold {
                    currentPhase = .down
                    feedback = .holdingDown
                } else if angle < (upThreshold - 15) {
                    feedback = .goingDown
                }
            }
            return false

        case .down:
            // Looking for user to come back UP
            if isInvertedExercise {
                // Angle increases when going up
                if angle > upThreshold {
                    return completeRep()
                } else if angle > (downThreshold + 20) {
                    feedback = .goingUp
                }
            } else {
                // Angle increases when going up
                if angle > upThreshold {
                    return completeRep()
                } else if angle > (downThreshold + 15) {
                    feedback = .goingUp
                }
            }
            return false
        }
    }

    private func completeRep() -> Bool {
        // Debounce check
        let now = Date()
        guard now.timeIntervalSince(lastRepTime) > debounceInterval else {
            return false
        }

        lastRepTime = now
        currentPhase = .up
        repCount += 1
        feedback = .repComplete

        triggerHaptic()

        // Reset feedback after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if self?.feedback == .repComplete {
                self?.feedback = .ready
            }
        }

        return true
    }

    private func triggerHaptic() {
        hapticGenerator.impactOccurred()
    }
}
