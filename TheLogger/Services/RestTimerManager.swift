//
//  RestTimerManager.swift
//  TheLogger
//
//  Observable timer manager for rest periods between sets
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Rest Timer Manager

/// Observable timer manager for rest periods between sets
@Observable
nonisolated final class RestTimerManager {
    static let shared = RestTimerManager()

    // Timer state
    var isActive: Bool = false
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 90  // Default rest time
    var isComplete: Bool = false

    // "Ready to start" state - shows rest option button
    var showRestOption: Bool = false
    var suggestedDuration: Int = 90

    // Track which exercise the timer is for
    var activeExerciseId: UUID?

    // Background handling
    private var backgroundTime: Date?
    private var timer: Timer?

    private init() {
        setupBackgroundObservers()
    }

    /// Internal initializer for unit testing — skips background observers.
    init(forTesting: Bool) {}


    // MARK: - Public API

    /// Show rest option after a set is logged
    /// - Parameters:
    ///   - exerciseId: The exercise this rest is for
    ///   - duration: Suggested rest duration in seconds (nil = use user's setting)
    ///   - autoStart: If true, timer starts immediately instead of showing option
    func offerRest(for exerciseId: UUID, duration: Int? = nil, autoStart: Bool = false) {
        debugLog("[RestTimer] offerRest called - isActive=\(isActive), isComplete=\(isComplete), showRestOption=\(showRestOption)")

        // Don't interrupt an active timer, but allow if timer is complete (waiting to dismiss)
        guard !isActive || isComplete else {
            debugLog("[RestTimer] offerRest BLOCKED by guard")
            return
        }

        // If timer was complete, reset it first
        if isComplete {
            debugLog("[RestTimer] Resetting complete timer")
            timer?.invalidate()
            timer = nil
            isActive = false
            isComplete = false
        }

        debugLog("[RestTimer] offerRest proceeding for exercise \(exerciseId)")
        activeExerciseId = exerciseId
        // Use provided duration, or user's setting, or fallback to 90
        let userDefault = UserDefaults.standard.integer(forKey: "defaultRestSeconds")
        suggestedDuration = duration ?? (userDefault > 0 ? userDefault : 90)
        isComplete = false

        if autoStart {
            // Start immediately
            debugLog("[RestTimer] autoStart=true, starting timer")
            showRestOption = false
            start()
        } else {
            // Show option button with animation
            debugLog("[RestTimer] Setting showRestOption=true for exercise \(exerciseId)")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showRestOption = true
            }
            debugLog("[RestTimer] showRestOption is now \(showRestOption)")
        }
    }

    /// Start the timer (user initiated)
    func start() {
        guard let exerciseId = activeExerciseId else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showRestOption = false
            totalSeconds = suggestedDuration
            remainingSeconds = suggestedDuration
            isActive = true
            isComplete = false
        }

        startTimer()
    }

    /// Start with specific duration
    func start(for exerciseId: UUID, duration: Int) {
        stop()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            activeExerciseId = exerciseId
            totalSeconds = duration
            remainingSeconds = duration
            isActive = true
            isComplete = false
            showRestOption = false
        }

        startTimer()
    }

    /// Stop and hide everything
    func stop() {
        debugLog("[RestTimer] stop() called")
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            isActive = false
            isComplete = false
            showRestOption = false
            activeExerciseId = nil
        }
        debugLog("[RestTimer] stop() complete - all state reset to nil/false")
    }

    /// Dismiss rest option without starting timer
    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showRestOption = false
            if !isActive {
                activeExerciseId = nil
            }
        }
    }

    /// Adjust suggested duration when offering rest (before start). Clamped 15–600 seconds.
    func adjustSuggestedDuration(delta: Int) {
        guard showRestOption, !isActive else { return }
        suggestedDuration = min(600, max(15, suggestedDuration + delta))
    }

    /// Set suggested duration when offering rest. Clamped 15–600 seconds.
    func setSuggestedDuration(_ seconds: Int) {
        guard showRestOption, !isActive else { return }
        suggestedDuration = min(600, max(15, seconds))
    }

    /// Add seconds to remaining time when timer is active.
    func addSeconds(_ n: Int) {
        guard isActive, n > 0 else { return }
        remainingSeconds = min(600, remainingSeconds + n)
        totalSeconds = max(totalSeconds, remainingSeconds)
        Analytics.send(Analytics.Signal.restTimerExtended, parameters: [
            "addedSeconds": "\(n)"
        ])
    }

    /// Skip the current rest period
    func skip() {
        Analytics.send(Analytics.Signal.restTimerSkipped, parameters: [
            "remainingSeconds": "\(remainingSeconds)"
        ])
        stop()
    }

    /// Pause timer (when user starts adding a set)
    func pause() {
        debugLog("[RestTimer] pause() called - isActive=\(isActive), showRestOption=\(showRestOption)")
        timer?.invalidate()
        timer = nil
        // Also hide rest option when user starts adding
        showRestOption = false
        debugLog("[RestTimer] pause() complete - showRestOption=\(showRestOption)")
    }

    /// Resume timer after pause
    func resume() {
        guard isActive && remainingSeconds > 0 else { return }
        startTimer()
    }

    /// Check if should show anything for this exercise
    func shouldShowFor(exerciseId: UUID) -> Bool {
        let result = activeExerciseId == exerciseId && (showRestOption || isActive)
        debugLog("[RestTimer] shouldShowFor(\(exerciseId)) - activeExerciseId=\(String(describing: activeExerciseId)), showRestOption=\(showRestOption), isActive=\(isActive) → \(result)")
        return result
    }

    /// Check if timer is actively running for a specific exercise
    func isActiveFor(exerciseId: UUID) -> Bool {
        isActive && activeExerciseId == exerciseId
    }

    /// Check if showing rest option for a specific exercise
    func isOfferingRestFor(exerciseId: UUID) -> Bool {
        showRestOption && activeExerciseId == exerciseId && !isActive
    }

    // MARK: - Progress

    /// Progress from 0.0 to 1.0
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    /// Formatted time string (mm:ss)
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            complete()
            return
        }
        remainingSeconds -= 1

        if remainingSeconds == 0 {
            complete()
        }
    }

    private func complete() {
        // Guard against double-completion
        guard isActive && !isComplete else { return }

        timer?.invalidate()
        timer = nil
        isComplete = true

        Analytics.send(Analytics.Signal.restTimerCompleted, parameters: [
            "durationSeconds": "\(totalSeconds)"
        ])

        // Haptic feedback when timer completes
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else {
                debugLog("[RestTimer] auto-dismiss: self is nil")
                return
            }
            debugLog("[RestTimer] auto-dismiss fired - isComplete=\(self.isComplete)")
            guard self.isComplete else {
                debugLog("[RestTimer] auto-dismiss skipped (isComplete=false)")
                return
            }
            debugLog("[RestTimer] auto-dismiss calling stop()")
            self.stop()
        }
    }

    // MARK: - Background Handling

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleForeground()
        }
    }

    private func handleBackground() {
        guard isActive else { return }
        backgroundTime = Date()
        timer?.invalidate()
        timer = nil
    }

    private func handleForeground() {
        guard isActive, !isComplete, let backgroundTime = backgroundTime else { return }

        let elapsed = Int(Date().timeIntervalSince(backgroundTime))
        remainingSeconds = max(0, remainingSeconds - elapsed)
        self.backgroundTime = nil

        if remainingSeconds > 0 {
            startTimer()
        } else {
            complete()
        }
    }
}
