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
    @Environment(ProManager.self) private var proManager

    // Upgrade gate
    @State private var showUpgrade = false

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

    // Share card
    @State private var peakContractionFrame: UIImage?
    @State private var shareCardConfig: ShareCardConfig?
    @State private var showShareCard = false

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
            if !proManager.canUseCamera {
                cameraLimitView
            } else {
                switch cameraPermission {
                case .authorized:
                    cameraContentView
                        .onAppear { proManager.recordCameraSession() }
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
        }
        .task {
            checkCameraPermission()
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
                .environment(proManager)
        }
    }

    // MARK: - Camera Limit View

    private var cameraLimitView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }

                VStack(spacing: 8) {
                    Text("Monthly Limit Reached")
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(.white)
                    Text("You've used all \(ProManager.cameraSessionLimit) free camera sessions this month.")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button {
                        showUpgrade = true
                    } label: {
                        Text("Upgrade to Pro")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)

                    Button("Not Now") { dismiss() }
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
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
                    poseConfidence: $poseConfidence,
                    peakContractionFrame: $peakContractionFrame
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
            peakContractionFrame = nil
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
        .sheet(isPresented: $showShareCard) {
            if let config = shareCardConfig {
                ShareCardEditorView(
                    config: Binding(
                        get: { shareCardConfig ?? config },
                        set: { shareCardConfig = $0 }
                    ),
                    onSkip: {
                        showShareCard = false
                        shareCardConfig = nil
                    },
                    onShare: { card in
                        proManager.recordShareCard()
                        let av = UIActivityViewController(activityItems: [card], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            var topVC = windowScene.windows.first?.rootViewController
                            while let presented = topVC?.presentedViewController {
                                topVC = presented
                            }
                            topVC?.present(av, animated: true)
                        }
                    }
                )
            }
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
                Analytics.send(Analytics.Signal.cameraClosed, parameters: ["repsLogged": "\(loggedSets.count)"])
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
        Analytics.send(Analytics.Signal.cameraSetLogged, parameters: [
            "exerciseName": exerciseName,
            "reps": "\(repCount)",
            "weight": "\(weight)"
        ])

        // Track for history display
        loggedSets.append((reps: repCount, weight: weight, rejectedShallow: shallowCount, rejectedFast: fastCount))

        // Generate share card if we captured a peak frame and user has share cards remaining
        if let frame = peakContractionFrame, proManager.canUseShareCard {
            let weightStorage = UnitFormatter.convertToStorage(weight)
            let est1RMStorage = weightStorage * (1.0 + Double(repCount) / 30.0)
            let est1RMDisplay = UnitFormatter.convertToDisplay(est1RMStorage)
            var config = ShareCardConfig(
                photo: frame,
                exerciseName: exerciseName,
                reps: repCount,
                weight: weight,
                weightUnit: UnitFormatter.weightUnit,
                estimated1RM: est1RMDisplay,
                isPR: false
            )
            config.isPhotoFlipped = true  // front camera frames are mirrored — auto-correct
            shareCardConfig = config
            peakContractionFrame = nil
            withAnimation(.spring(response: 0.3)) {
                showShareCard = true
            }
        } else {
            peakContractionFrame = nil
        }

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

    // MARK: - Share Card Sheet (see ShareCardEditorView below)

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

// MARK: - Share Card Editor

/// Self-contained share card editor sheet.
/// Owns all picker state so parent re-renders cannot accidentally dismiss open pickers.
private struct ShareCardEditorView: View {
    @Binding var config: ShareCardConfig
    var onSkip: () -> Void
    var onShare: (UIImage) -> Void

    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var showReplacePhotoOptions = false
    @State private var useFrontCamera = false
    @State private var thumbnails: [CardTheme: UIImage] = [:]
    @State private var backgroundSwatches: [CardBackground: UIImage] = [:]

    // Original photo captured at init — used to restore if user wants to undo selfie/library replacement
    private let originalPhoto: UIImage
    private let originalIsFlipped: Bool

    init(config: Binding<ShareCardConfig>, onSkip: @escaping () -> Void, onShare: @escaping (UIImage) -> Void) {
        self._config = config
        self.onSkip = onSkip
        self.onShare = onShare
        self.originalPhoto = config.wrappedValue.photo
        self.originalIsFlipped = config.wrappedValue.isPhotoFlipped
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Live interactive preview + replace photo overlay button
                    CardLivePreview(config: $config)
                        .padding(.horizontal, 60)
                        .overlay(alignment: .topTrailing) {
                            Button { showReplacePhotoOptions = true } label: {
                                Image(systemName: "camera.on.rectangle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .padding(.top, 6)
                            .padding(.trailing, 68)
                        }

                    // Filter thumbnail strip
                    filterStripView

                    // Background picker
                    backgroundPickerRow

                    // Stat toggle chips
                    statToggleRow

                    // Skip / Share buttons
                    HStack(spacing: 12) {
                        Button("Skip") { onSkip() }
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            if let card = WorkoutCardRenderer.render(config: config) {
                                onShare(card)
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Share Your Set")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { generateThumbnails() }
            .onChange(of: config.photo) { _, _ in generateThumbnails() }
            .onChange(of: config.theme) { _, _ in generateBackgroundSwatches() }
            .confirmationDialog("Replace Photo", isPresented: $showReplacePhotoOptions) {
                Button("Take Photo") { useFrontCamera = false; showCameraPicker = true }
                Button("Take Selfie") { useFrontCamera = true; showCameraPicker = true }
                Button("Choose from Library") { showPhotoPicker = true }
                Button("Reset to Original") {
                    config.photo = originalPhoto
                    config.isPhotoFlipped = originalIsFlipped
                    config.photoScale = 1.0
                    config.photoOffset = .zero
                    config.statsOffset = .zero
                    config.statsScale = 1.0
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView(selectedImage: Binding(
                    get: { nil },
                    set: { if let img = $0 {
                        config.photo = img
                        config.isPhotoFlipped = false
                        config.photoScale = 1.0
                        config.photoOffset = .zero
                        config.statsOffset = .zero
                        config.statsScale = 1.0
                    }}
                ), onDismiss: {})
            }
            .sheet(isPresented: $showCameraPicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    CameraPickerView(cameraDevice: useFrontCamera ? .front : .rear) { img in
                        config.photo = img.normalizedOrientation()
                        config.isPhotoFlipped = useFrontCamera
                        config.photoScale = 1.0
                        config.photoOffset = .zero
                        config.statsOffset = .zero
                        config.statsScale = 1.0
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Filter Strip

    private var filterStripView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CardTheme.allCases, id: \.self) { theme in
                    FilterThumbnailItem(
                        theme: theme,
                        thumbnail: thumbnails[theme],
                        isSelected: config.theme == theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) { config.theme = theme }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)   // room for scaleEffect expansion
        }
    }

    private func generateThumbnails() {
        thumbnails = [:]
        backgroundSwatches = [:]
        let rawPhoto = config.photo
        let isFlipped = config.isPhotoFlipped
        let theme = config.theme
        // Run all filter + swatch tasks concurrently — much faster on multi-core
        Task.detached(priority: .userInitiated) {
            // Pre-downscale once — avoids decoding a 12MP image per concurrent task
            let workPhoto = rawPhoto.scaledDown(toMaxDimension: 512)
            // Apply flip correction so thumbnails match the final rendered card
            let displayPhoto = isFlipped ? workPhoto.flippedHorizontally() : workPhoto
            await withTaskGroup(of: Void.self) { group in
                for cardTheme in CardTheme.allCases {
                    group.addTask {
                        if let thumb = WorkoutCardRenderer.thumbnailImage(photo: displayPhoto, theme: cardTheme) {
                            await MainActor.run { thumbnails[cardTheme] = thumb }
                        }
                    }
                }
                for bg in CardBackground.allCases {
                    group.addTask {
                        if let swatch = WorkoutCardRenderer.backgroundSwatch(photo: displayPhoto, background: bg, theme: theme) {
                            await MainActor.run { backgroundSwatches[bg] = swatch }
                        }
                    }
                }
            }
        }
    }

    private func generateBackgroundSwatches() {
        backgroundSwatches = [:]
        let rawPhoto = config.photo
        let isFlipped = config.isPhotoFlipped
        let theme = config.theme
        Task.detached(priority: .userInitiated) {
            let workPhoto = rawPhoto.scaledDown(toMaxDimension: 512)
            let displayPhoto = isFlipped ? workPhoto.flippedHorizontally() : workPhoto
            await withTaskGroup(of: Void.self) { group in
                for bg in CardBackground.allCases {
                    group.addTask {
                        if let swatch = WorkoutCardRenderer.backgroundSwatch(photo: displayPhoto, background: bg, theme: theme) {
                            await MainActor.run { backgroundSwatches[bg] = swatch }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Background Picker

    private var backgroundPickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CardBackground.allCases, id: \.self) { bg in
                    BackgroundSwatchItem(
                        background: bg,
                        swatch: backgroundSwatches[bg],
                        isSelected: config.background == bg
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) { config.background = bg }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)   // room for scaleEffect expansion
        }
    }

    // MARK: - Stat Chips

    private var statToggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                statChip("Exercise", isOn: $config.showExerciseName)
                statChip("Weight × Reps", isOn: $config.showWeightReps)
                statChip("Est. 1RM", isOn: $config.show1RM)
                statChip("Date", isOn: $config.showDate)
            }
            .padding(.horizontal)
        }
    }

    private func statChip(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                if isOn.wrappedValue {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(.subheadline, weight: .medium))
            }
            .foregroundStyle(isOn.wrappedValue ? .white : AppColors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn.wrappedValue ? AppColors.accent : AppColors.accent.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppColors.accent.opacity(isOn.wrappedValue ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Thumbnail Item

private struct FilterThumbnailItem: View {
    let theme: CardTheme
    let thumbnail: UIImage?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 96)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemFill))
                            .frame(width: 54, height: 96)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.secondary)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(duration: 0.2), value: isSelected)

                Text(theme.displayName)
                    .font(.system(size: 8, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Background Views

/// Live preview background — GPU-accelerated SwiftUI approximation (no Core Image needed for preview).
private struct BackgroundView: View {
    let config: ShareCardConfig
    let photo: UIImage

    var body: some View {
        // Always a ZStack — avoids mixed-type switch return which can cause runtime layout failures.
        ZStack {
            // Base colour layer
            if config.background == .light {
                Color(red: 0.94, green: 0.93, blue: 0.92)
            } else {
                Color.black
            }

            // Blur layer (opaque blur avoids edge transparency artefacts)
            if config.background == .blur {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18, opaque: true)
                Color.black.opacity(0.38)
            }

            // Gradient layer
            if config.background == .gradient {
                RadialGradient(
                    colors: [config.theme.accentSwiftUI.opacity(0.35), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 260
                )
            }
        }
    }
}

/// Swatch item for the background picker row.
private struct BackgroundSwatchItem: View {
    let background: CardBackground
    let swatch: UIImage?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Group {
                    if let img = swatch {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 96)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(background == .light ? Color(white: 0.93) : Color.black)
                            .frame(width: 54, height: 96)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(duration: 0.2), value: isSelected)

                Text(background.displayName)
                    .font(.system(size: 8, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live Card Preview

/// Interactive 9:16 card preview. Photo and stats overlay are separate layers with independent gestures.
private struct CardLivePreview: View {
    @Binding var config: ShareCardConfig

    // Cached display-ready image — avoids calling flippedHorizontally() every render frame
    @State private var displayPhoto: UIImage
    // CI-filtered version of displayPhoto for accurate theme preview
    @State private var filteredPhoto: UIImage? = nil

    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var photoDrag: CGSize = .zero
    @GestureState private var statsDrag: CGSize = .zero
    @GestureState private var statsLivePinch: CGFloat = 1.0

    // Canvas constants
    private let canvasW: CGFloat = 1080
    private let canvasH: CGFloat = 1920

    init(config: Binding<ShareCardConfig>) {
        self._config = config
        let c = config.wrappedValue
        self._displayPhoto = State(initialValue:
            c.isPhotoFlipped ? c.photo.flippedHorizontally() : c.photo)
    }

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width  / canvasW
            let sy = geo.size.height / canvasH

            ZStack {
                // 1. Background
                BackgroundView(config: config, photo: displayPhoto)
                    .animation(.easeInOut(duration: 0.18), value: config.background)

                // 2. Photo layer — pinch to zoom, drag to pan
                let photoRect = computePhotoRect(geo: geo)
                let liveW = photoRect.width  * pinchScale
                let liveH = photoRect.height * pinchScale
                let liveCX = photoRect.midX + photoDrag.width
                let liveCY = photoRect.midY + photoDrag.height

                Image(uiImage: filteredPhoto ?? displayPhoto)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: liveW, height: liveH)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .position(x: liveCX, y: liveCY)
                    .animation(.easeInOut(duration: 0.18), value: config.theme)
                    .drawingGroup()
                    .gesture(
                        MagnificationGesture()
                            .updating($pinchScale) { v, s, _ in s = v }
                            .onEnded { v in
                                config.photoScale = min(max(config.photoScale * v, 0.5), 4.0)
                            }
                            .simultaneously(with:
                                DragGesture(minimumDistance: 4)
                                    .updating($photoDrag) { v, s, _ in s = v.translation }
                                    .onEnded { v in
                                        config.photoOffset.x += v.translation.width  / sx
                                        config.photoOffset.y += v.translation.height / sy
                                    }
                            )
                    )

                // 3. Vignette
                RadialGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    center: .center,
                    startRadius: 0,
                    endRadius: geo.size.height * 0.6
                )
                .allowsHitTesting(false)

                // 4. Stats overlay — drag to move, pinch to resize (hidden when no stats selected)
                if config.hasAnyStats {
                let statsCenter = computeStatsCenter(geo: geo)
                StatsCardView(config: config, width: canvasW * 0.83 * sx)
                    .scaleEffect(config.statsScale * statsLivePinch)
                    .position(
                        x: statsCenter.x + statsDrag.width,
                        y: statsCenter.y + statsDrag.height
                    )
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .updating($statsDrag) { v, s, _ in s = v.translation }
                            .onEnded { v in
                                config.statsOffset.x += v.translation.width  / sx
                                config.statsOffset.y += v.translation.height / sy
                            }
                            .simultaneously(with:
                                MagnificationGesture()
                                    .updating($statsLivePinch) { v, s, _ in s = v }
                                    .onEnded { v in
                                        config.statsScale = min(max(config.statsScale * v, 0.3), 3.0)
                                    }
                            )
                    )
                } // end if config.hasAnyStats
            }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        // Branding overlay — placed outside ZStack so it's never covered by photo/compositing layers
        .overlay(alignment: .bottomTrailing) {
            Text("TheLogger")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                .padding(14)
                .allowsHitTesting(false)
        }
        .onAppear { applyFilterAsync() }
        .onChange(of: config.photo) { _, _ in refreshDisplayPhoto() }
        .onChange(of: config.isPhotoFlipped) { _, _ in refreshDisplayPhoto() }
        .onChange(of: displayPhoto) { _, _ in filteredPhoto = nil; applyFilterAsync() }
        .onChange(of: config.theme) { _, _ in filteredPhoto = nil; applyFilterAsync() }
    }

    private func refreshDisplayPhoto() {
        displayPhoto = config.isPhotoFlipped
            ? config.photo.flippedHorizontally()
            : config.photo
    }

    /// Applies the selected Core Image theme filter to displayPhoto in the background,
    /// giving a pixel-accurate preview that matches the final rendered card.
    private func applyFilterAsync() {
        let photo = displayPhoto
        let theme = config.theme
        Task.detached(priority: .userInitiated) {
            // Pre-convert to sRGB via UIGraphicsImageRenderer (same as thumbnail generation).
            // This prevents P3 wide-gamut photos from producing blown-out results in
            // CITemperatureAndTint filters (PORTRA, GOLDEN HOUR), matching thumbnail appearance.
            let workPhoto = photo.scaledDown(toMaxDimension: 512)
            let result = WorkoutCardRenderer.applyPhotoFilter(to: workPhoto, theme: theme)
            await MainActor.run { filteredPhoto = result }
        }
    }

    /// Photo rect in screen-space, matching the renderer's aspect-fit + scale + offset logic.
    private func computePhotoRect(geo: GeometryProxy) -> CGRect {
        let sx = geo.size.width  / canvasW
        let sy = geo.size.height / canvasH
        let photoSize = config.photo.size
        guard photoSize.width > 0, photoSize.height > 0 else {
            return CGRect(origin: .zero, size: geo.size)
        }
        let fitScale = min(canvasW / photoSize.width, canvasH / photoSize.height)
        let fitW = photoSize.width  * fitScale * config.photoScale
        let fitH = photoSize.height * fitScale * config.photoScale
        let centerX = (canvasW / 2 + config.photoOffset.x) * sx
        let centerY = (canvasH / 2 + config.photoOffset.y) * sy
        return CGRect(
            x: centerX - fitW * sx / 2,
            y: centerY - fitH * sy / 2,
            width:  fitW * sx,
            height: fitH * sy
        )
    }

    /// Stats card center in screen-space.
    private func computeStatsCenter(geo: GeometryProxy) -> CGPoint {
        let sx = geo.size.width  / canvasW
        let sy = geo.size.height / canvasH
        let canvasCX = canvasW / 2  + config.statsOffset.x
        let canvasCY = canvasH * 0.58 + config.statsOffset.y
        return CGPoint(x: canvasCX * sx, y: canvasCY * sy)
    }
}

// MARK: - Stats Card View (live preview approximation)

private struct StatsCardView: View {
    let config: ShareCardConfig
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if config.showExerciseName {
                Text(config.exerciseName.uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            if config.showWeightReps {
                Text("\(Int(config.weight)) \(config.weightUnit) × \(config.reps)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(config.theme.accentSwiftUI)
            }
            if config.show1RM {
                Text("est. 1RM  \(Int(config.estimated1RM)) \(config.weightUnit)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
            }
            if config.isPR {
                Text("🏆  NEW PR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.09))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(config.theme.accentSwiftUI)
                    .clipShape(Capsule())
            }
            if config.showDate {
                Text(Date(), style: .date)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .padding(14)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.10, green: 0.09, blue: 0.09).opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
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
