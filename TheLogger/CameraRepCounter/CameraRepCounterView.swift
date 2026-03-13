//
//  CameraRepCounterView.swift
//  TheLogger
//
//  Main SwiftUI view for camera-based rep counting
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraRepCounterView: View {

    // MARK: - Properties

    let exerciseName: String
    let lastWeight: Double
    let onSetLogged: (Int, Double) -> Void

    @Environment(\.dismiss) private var dismiss

    // State
    @State private var repCount = 0
    @State private var weight: Double
    @State private var currentAngle: Double = 0
    @State private var feedback: RepCounter.MovementFeedback = .settingUp
    @State private var detectedPose: DetectedPose?
    @State private var selectedExerciseType: ExerciseType
    @State private var showExercisePicker = false
    @State private var isPaused = false

    // Camera permission
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined

    // Skeleton toggle
    @AppStorage("showSkeletonOverlay") private var showSkeleton = true

    // Sensitivity (0=Strict, 1=Normal, 2=Easy)
    @AppStorage("repCounterSensitivity") private var sensitivity: Int = 1

    // Calibration overlay
    @State private var showCalibrationOverlay = true
    @State private var calibrationDismissed = false

    // Phone orientation warning
    @State private var isTooFlat = false

    // Low confidence
    @State private var isLowConfidence = false
    @State private var poseConfidence: Double = 0
    @State private var showTorchSuggestion = false

    // Exercise auto-detection
    @State private var exerciseAutoDetected: Bool

    // Rep counter (needs to persist during view updates)
    @State private var repCounter: RepCounter

    // Rep flash
    @State private var showRepFlash = false

    // Multi-set flow
    @State private var loggedSets: [(reps: Int, weight: Double, rejectedShallow: Int, rejectedFast: Int)] = []
    @State private var showSetLoggedConfirmation = false

    // Rejection toast
    @State private var showRejectionToast = false
    @State private var rejectionMessage = ""

    // Computed
    private var exerciseType: ExerciseType {
        selectedExerciseType
    }

    private var feedbackColor: Color {
        switch feedback {
        case .settingUp: return .white.opacity(0.5)
        case .almostReady: return .yellow.opacity(0.7)
        case .armed: return .green
        case .ready: return .white.opacity(0.7)
        case .goingDown, .goingUp: return .yellow
        case .holdingDown: return AppColors.accent
        case .repComplete: return .green
        case .tooShallow, .tooFast: return .orange
        case .noDetection: return .red.opacity(0.7)
        case .lowVisibility: return .orange.opacity(0.7)
        }
    }

    /// Edge glow color based on current feedback state — visible from any distance
    private var edgeGlowColor: Color {
        switch feedback {
        case .settingUp, .noDetection: return .clear
        case .almostReady: return .yellow.opacity(0.4)
        case .armed, .ready: return .green.opacity(0.7)
        case .goingDown, .goingUp: return .yellow.opacity(0.6)
        case .holdingDown: return AppColors.accent
        case .repComplete: return .green
        case .tooShallow, .tooFast: return .orange.opacity(0.5)
        case .lowVisibility: return .red.opacity(0.4)
        }
    }

    /// Tracking quality based on pose detection confidence
    private var trackingQuality: (color: Color, label: String) {
        guard let pose = detectedPose else {
            return (.red.opacity(0.7), "No tracking")
        }
        let confidence = Double(pose.confidence)
        if confidence > 0.7 {
            return (.green, "Good")
        } else if confidence > 0.4 {
            return (.yellow, "Fair")
        } else {
            return (.red.opacity(0.7), "Poor")
        }
    }

    // MARK: - Initialization

    init(exerciseName: String, lastWeight: Double, onSetLogged: @escaping (Int, Double) -> Void) {
        self.exerciseName = exerciseName
        self.lastWeight = lastWeight
        self.onSetLogged = onSetLogged

        self._weight = State(initialValue: UnitFormatter.convertToDisplay(lastWeight))

        let detectedType = ExerciseType.from(exerciseName: exerciseName)
        self._exerciseAutoDetected = State(initialValue: detectedType != nil)
        let exerciseType = detectedType ?? .squat
        self._selectedExerciseType = State(initialValue: exerciseType)
        self._repCounter = State(initialValue: RepCounter(exerciseType: exerciseType))

        // Skip calibration if user has already seen it for this exercise type
        let seen = UserDefaults.standard.bool(forKey: "calibrationSeen_\(exerciseType.rawValue)")
        self._showCalibrationOverlay = State(initialValue: !seen)
        self._calibrationDismissed = State(initialValue: seen)
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch cameraPermission {
            case .authorized:
                cameraContentView
            case .denied, .restricted:
                permissionDeniedView
            case .notDetermined:
                ProgressView("Requesting camera access...")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            @unknown default:
                permissionDeniedView
            }
        }
        .task {
            checkCameraPermission()
        }
    }

    // MARK: - Camera Content View

    private var cameraContentView: some View {
        ZStack {
            // Camera feed with pose overlay
            if !isPaused {
                CameraPreviewView(
                    repCount: $repCount,
                    currentAngle: $currentAngle,
                    feedback: $feedback,
                    detectedPose: $detectedPose,
                    exerciseType: exerciseType,
                    repCounter: repCounter,
                    showSkeleton: $showSkeleton,
                    isTooFlat: $isTooFlat,
                    isLowConfidence: $isLowConfidence,
                    poseConfidence: $poseConfidence
                )
                .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("Camera Paused")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
            }

            // Edge glow overlay — state visible from 6ft away
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(edgeGlowColor, lineWidth: 15)
                .blur(radius: 8)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.25), value: feedback)

            // Full-screen green flash on rep completion
            Color.green
                .opacity(showRepFlash ? 0.35 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.3), value: showRepFlash)

            // UI Overlay
            VStack(spacing: 0) {
                // Header
                headerView
                    .background(.ultraThinMaterial.opacity(0.8))

                // Low visibility banner
                if isLowConfidence {
                    lowVisibilityBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Phone too flat warning
                if isTooFlat && !isLowConfidence {
                    tooFlatWarningView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Stability progress bar (during idle/arming)
                if repCounter.currentPhase == .idle && repCounter.stabilityProgress > 0 {
                    stabilityProgressBar
                        .transition(.opacity)
                }

                Spacer()

                // Rep counter display
                repCounterDisplay

                Spacer()

                // Rejection toast
                if showRejectionToast {
                    rejectionToastView
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .padding(.bottom, 4)
                }

                // Feedback indicator
                feedbackView
                    .padding(.bottom, 20)

                // Bottom controls
                bottomControls
                    .background(.ultraThinMaterial.opacity(0.9))
            }

            // Calibration overlay
            if showCalibrationOverlay && !isPaused {
                calibrationOverlayView
                    .transition(.opacity)
            }

            // Set logged confirmation overlay
            if showSetLoggedConfirmation {
                setLoggedConfirmationView
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .onChange(of: selectedExerciseType) { _, newType in
            repCounter.reset()
            repCount = 0
            // Check if calibration was already seen for the new exercise type
            let seen = UserDefaults.standard.bool(forKey: "calibrationSeen_\(newType.rawValue)")
            if seen {
                showCalibrationOverlay = false
                calibrationDismissed = true
            } else {
                showCalibrationOverlay = true
                calibrationDismissed = false
            }
        }
        .onChange(of: repCounter.lastRejectionReason) { _, reason in
            guard reason != .none else { return }
            showRejectionToast(for: reason)
        }
        .onChange(of: repCount) { oldValue, newValue in
            // Flash green only when rep counter increases from camera detection
            guard newValue > oldValue, feedback == .repComplete else { return }
            showRepFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showRepFlash = false
            }
        }
        .onChange(of: sensitivity) { _, newValue in
            applySensitivity(newValue, to: repCounter)
        }
        .onChange(of: isLowConfidence) { _, isLow in
            if isLow {
                // Show torch suggestion after 3s of sustained low confidence
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if isLowConfidence {
                        withAnimation { showTorchSuggestion = true }
                    }
                }
            } else {
                withAnimation { showTorchSuggestion = false }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            applySensitivity(sensitivity, to: repCounter)
            if !exerciseAutoDetected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showExercisePicker = true
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showExercisePicker) {
            exercisePickerSheet
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("Camera Access Required")
                .font(.title2.weight(.semibold))

            Text("TheLogger needs camera access to track your reps using pose detection. Your camera feed is processed on-device and never leaves your phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Go Back")
                        .font(.headline)
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Calibration Overlay

    private var calibrationOverlayView: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCalibration()
                }

            VStack(spacing: 20) {
                // Dismiss button
                HStack {
                    Spacer()
                    Button {
                        dismissCalibration()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Image(systemName: "figure.stand")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Position Yourself")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text(exerciseType.framingTip)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(exerciseType.setupTip)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(exerciseType.repDescription)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

                Label(exerciseType.trackingNote, systemImage: "arrow.left.arrow.right")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Low Visibility Banner

    private var lowVisibilityBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Low visibility")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Move to a brighter area — rep counting paused")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }

            if showTorchSuggestion {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                    Text("Tip: Try facing a window or light source")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.7), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .animation(.easeInOut(duration: 0.3), value: isLowConfidence)
    }

    // MARK: - Too Flat Warning

    private var tooFlatWarningView: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Prop your phone upright")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Lean it against a wall or use a stand. Flat on the floor won't work.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.7), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .animation(.easeInOut(duration: 0.3), value: isTooFlat)
    }

    // MARK: - Stability Progress Bar

    private var stabilityProgressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: repCounter.stabilityProgress)
                .tint(.green)
                .frame(height: 4)
                .padding(.horizontal, 40)

            Text("Hold steady...")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 8)
    }

    // MARK: - Rejection Toast

    private var rejectionToastView: some View {
        Text(rejectionMessage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.8))
            )
    }

    private func showRejectionToast(for reason: RepCounter.RejectionReason) {
        let message: String
        let duration: TimeInterval

        switch reason {
        case .tooShallow:
            message = "Go deeper"
            duration = 0.8
        case .tooFast:
            message = "Too fast"
            duration = 0.5
        case .notArmed:
            message = "Hold still to start"
            duration = 1.0
        case .lowConfidence:
            message = "Can't see you clearly"
            duration = 1.0
        case .none:
            return
        }

        withAnimation(.easeIn(duration: 0.15)) {
            rejectionMessage = message
            showRejectionToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.2)) {
                showRejectionToast = false
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            // Exercise name and type selector
            VStack(spacing: 2) {
                Text(exerciseName)
                    .font(.headline)
                    .foregroundStyle(.white)

                Button {
                    showExercisePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: exerciseType.systemImage)
                        Text(exerciseType.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            // Tracking confidence indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(trackingQuality.color)
                    .frame(width: 8, height: 8)
                Text(trackingQuality.label)
                    .font(.caption2)
                    .foregroundStyle(trackingQuality.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.3)))
            .animation(.easeInOut(duration: 0.3), value: detectedPose?.confidence)

            // Instructions info button (visible after first dismissal)
            if calibrationDismissed {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showCalibrationOverlay = true
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Skeleton toggle
            Button {
                showSkeleton.toggle()
            } label: {
                Image(systemName: showSkeleton ? "eye.fill" : "eye.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Pause/Resume button
            Button {
                isPaused.toggle()
                repCounter.isActive = !isPaused
            } label: {
                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isPaused ? .green : .white.opacity(0.8))
            }
        }
        .padding()
    }

    private var repCounterDisplay: some View {
        VStack(spacing: 8) {
            // Rep count
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(repCount)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: repCount)

                // Low confidence indicator
                if repCounter.isLowConfidenceRep && repCount > 0 {
                    Text("?")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.yellow.opacity(0.7))
                }
            }

            Text("REPS")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(4)

            #if DEBUG
            VStack(spacing: 2) {
                Text("Angle: \(Int(currentAngle))°  Vel: \(String(format: "%.1f", repCounter.angularVelocity))  Phase: \(repCounter.currentPhase.rawValue)  Stab: \(String(format: "%.0f%%", repCounter.stabilityProgress * 100))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                Text("Frames: \(repCounter.debugAcceptedFrames)/\(repCounter.debugFrameCount)  Near: \(repCounter.debugIsNearStart ? "Y" : "N")  Still: \(repCounter.debugIsStable ? "Y" : "N")  Outlier: \(repCounter.debugLastOutlierRejected ? "REJ" : "ok")")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 8)
            #endif
        }
    }

    private var feedbackView: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(feedbackColor)
                .frame(width: 14, height: 14)

            Text(feedback.rawValue)
                .font(.title3.weight(.bold))
                .foregroundStyle(feedbackColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
        )
        .animation(.easeInOut(duration: 0.2), value: feedback)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Set history strip (shown after first logged set)
            if !loggedSets.isEmpty {
                setHistoryStrip
            }

            // Sensitivity picker
            Picker("Sensitivity", selection: $sensitivity) {
                Text("Strict").tag(0)
                Text("Normal").tag(1)
                Text("Easy").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Weight input
            HStack(spacing: 16) {
                Text("Weight:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 8) {
                    Button {
                        weight = max(0, weight - 5)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("\(Int(weight))")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 60)

                    Button {
                        weight += 5
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Text(UnitFormatter.weightUnit)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                // Manual rep adjustment
                HStack(spacing: 8) {
                    Button {
                        repCounter.removeRep()
                        repCount = repCounter.repCount
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Button {
                        repCounter.addRep()
                        repCount = repCounter.repCount
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal)

            // Action buttons
            HStack(spacing: 12) {
                // Reset button
                Button {
                    repCounter.reset()
                    repCount = 0
                } label: {
                    Text("Reset")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                }

                // Log set button — stays in camera, doesn't dismiss
                Button {
                    logCurrentSet()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(loggedSets.isEmpty ? "Log Set" : "Log Set \(loggedSets.count + 1)")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(repCount > 0 ? AppColors.accent : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(repCount == 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 16)
    }

    // MARK: - Set History Strip

    private var setHistoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(loggedSets.enumerated()), id: \.offset) { index, set in
                    Text("Set \(index + 1): \(set.reps)×\(Int(set.weight))")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Multi-Set Helpers

    private func logCurrentSet() {
        // Snapshot rejection counts before reset
        let shallowCount = repCounter.rejectedShallowCount
        let fastCount = repCounter.rejectedFastCount

        // Save set immediately (convert display value back to storage units — always lbs internally)
        onSetLogged(repCount, UnitFormatter.convertToStorage(weight))
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Track for history display
        loggedSets.append((reps: repCount, weight: weight, rejectedShallow: shallowCount, rejectedFast: fastCount))

        // Show confirmation
        withAnimation(.spring(response: 0.3)) {
            showSetLoggedConfirmation = true
        }

        // Reset for next set
        repCounter.reset()
        repCount = 0

        // Auto-hide confirmation after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSetLoggedConfirmation = false
            }
        }
    }

    // MARK: - Exercise Picker Sheet

    private var exercisePickerSheet: some View {
        NavigationStack {
            List {
                if !exerciseAutoDetected {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Not Available Yet", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.accent)

                            Text("Camera tracking isn't available for \"\(exerciseName)\" yet. Select a similar exercise type below.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Custom exercise tracking coming soon!")
                                .font(.caption)
                                .foregroundStyle(AppColors.accent)
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(ExerciseType.allCases.filter { $0.category == category }, id: \.self) { type in
                            Button {
                                selectedExerciseType = type
                                showExercisePicker = false
                            } label: {
                                HStack {
                                    Image(systemName: type.systemImage)
                                        .foregroundStyle(AppColors.accent)
                                        .frame(width: 30)

                                    Text(type.rawValue)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if type == selectedExerciseType {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppColors.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showExercisePicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Set Logged Confirmation

    private var setLoggedConfirmationView: some View {
        VStack(spacing: 6) {
            let setNumber = loggedSets.count
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Set \(setNumber) Logged!")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            if let lastSet = loggedSets.last {
                let parts = rejectionSummaryParts(shallow: lastSet.rejectedShallow, fast: lastSet.rejectedFast)
                if !parts.isEmpty {
                    Text(parts)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private func rejectionSummaryParts(shallow: Int, fast: Int) -> String {
        var parts: [String] = []
        if shallow > 0 { parts.append("\(shallow) shallow") }
        if fast > 0 { parts.append("\(fast) too fast") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Calibration Helpers

    private func dismissCalibration() {
        withAnimation(.easeOut(duration: 0.3)) {
            showCalibrationOverlay = false
            calibrationDismissed = true
        }
        UserDefaults.standard.set(true, forKey: "calibrationSeen_\(exerciseType.rawValue)")
    }

    // MARK: - Sensitivity Helpers

    private func applySensitivity(_ level: Int, to counter: RepCounter) {
        switch level {
        case 0: // Strict
            counter.sensitivityMultiplier = 0.5
            counter.minimumRepDurationOverride = 0.6
        case 2: // Easy
            counter.sensitivityMultiplier = 0.25
            counter.minimumRepDurationOverride = 0.4
        default: // Normal
            counter.sensitivityMultiplier = 0.4
            counter.minimumRepDurationOverride = 0.6
        }
    }

    // MARK: - Permission Helpers

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        } else {
            cameraPermission = status
        }
    }
}

// MARK: - Preview

#Preview {
    CameraRepCounterView(
        exerciseName: "Squat",
        lastWeight: 135,
        onSetLogged: { reps, weight in
            debugLog("Logged: \(reps) reps @ \(weight) lbs")
        }
    )
}
