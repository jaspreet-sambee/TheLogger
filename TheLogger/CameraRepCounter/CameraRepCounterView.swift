//
//  CameraRepCounterView.swift
//  TheLogger
//
//  Main SwiftUI view for camera-based rep counting
//

import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

struct CameraRepCounterView: View {

    // MARK: - Properties

    let exerciseName: String
    let lastWeight: Double
    let onSetLogged: (Int, Double, Double?, Double?) -> Void  // (reps, weight, tempoDown?, tempoUp?)

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

    // Share card — queued until camera close
    @State private var peakContractionFrame: UIImage?
    @State private var capturedFrames: [(config: ShareCardConfig, setNumber: Int)] = []
    @State private var showFrameGallery = false
    @State private var selectedGalleryConfig: ShareCardConfig?
    @State private var showGalleryShareCard = false

    // Hands-free mode
    @AppStorage("handsFreeMode") private var handsFreeMode: Bool = false

    // Auto-log countdown overlay
    @State private var showAutoLogCountdown = false
    @State private var autoLogCountdownSeconds: Int = 3
    @State private var autoLogCountdownTimer: Timer?

    // Camera auto-rest timer
    @State private var isResting = false
    @State private var restSecondsRemaining: Int = 0
    @State private var restTotalSeconds: Int = 90
    @State private var restTimer: Timer?
    @AppStorage("globalRestTimerEnabled") private var cameraRestEnabled: Bool = false
    @AppStorage("defaultRestSeconds") private var cameraRestDuration: Int = 90

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

    init(exerciseName: String, lastWeight: Double, onSetLogged: @escaping (Int, Double, Double?, Double?) -> Void) {
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
                    .background(Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.80))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }

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

                if isResting {
                    // Rest timer overlay on camera
                    Spacer()
                    cameraRestOverlay
                        .padding(.bottom, 20)

                    // Rest bottom controls
                    cameraRestBottomPanel
                        .background(Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.88))
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                        }
                } else {
                    // Feedback indicator
                    feedbackView
                        .padding(.bottom, 20)

                    // Bottom controls
                    bottomControls
                        .background(Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.88))
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                        }
                }
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

            // Hands-free auto-log countdown overlay
            if showAutoLogCountdown {
                autoLogCountdownOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(10)
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
            Analytics.send(Analytics.Signal.cameraExerciseChanged, parameters: ["exerciseName": newType.rawValue])
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
            Analytics.send(Analytics.Signal.cameraSensitivityChanged, parameters: ["sensitivity": "\(newValue)"])
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
        .onChange(of: repCounter.autoLogPending) { _, isPending in
            if isPending && handsFreeMode {
                startAutoLogCountdown()
            } else if isPending && !handsFreeMode {
                // Hands-free off — discard the signal
                repCounter.cancelAutoLog()
            } else if !isPending && showAutoLogCountdown {
                // User resumed reps mid-countdown — cancel silently
                cancelAutoLogCountdown(andLog: false)
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
            autoLogCountdownTimer?.invalidate()
            autoLogCountdownTimer = nil
        }
        .sheet(isPresented: $showExercisePicker) {
            exercisePickerSheet
        }
        .sheet(isPresented: $showFrameGallery) {
            FrameGalleryView(
                frames: capturedFrames,
                onSelect: { config in
                    selectedGalleryConfig = config
                    showFrameGallery = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showGalleryShareCard = true
                    }
                },
                onSkipAll: {
                    showFrameGallery = false
                    capturedFrames.removeAll()
                    dismiss()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGalleryShareCard) {
            if let config = selectedGalleryConfig {
                ShareCardEditorView(
                    config: Binding(
                        get: { selectedGalleryConfig ?? config },
                        set: { selectedGalleryConfig = $0 }
                    ),
                    onSkip: {
                        showGalleryShareCard = false
                        selectedGalleryConfig = nil
                        capturedFrames.removeAll()
                        dismiss()
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
                        capturedFrames.removeAll()
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
        HStack(spacing: 8) {
            // Close button — 32×32 circle (with frame count badge)
            Button {
                Analytics.send(Analytics.Signal.cameraClosed, parameters: ["repsLogged": "\(loggedSets.count)"])
                if !capturedFrames.isEmpty && proManager.canUseShareCard {
                    showFrameGallery = true
                } else {
                    dismiss()
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Text("✕")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        )
                    if !capturedFrames.isEmpty {
                        Text("\(capturedFrames.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(AppColors.accent))
                            .offset(x: 4, y: -4)
                    }
                }
            }

            // Title + exercise type subtitle
            VStack(spacing: 1) {
                Text(exerciseName)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .lineLimit(1)
                Button { showExercisePicker = true } label: {
                    HStack(spacing: 3) {
                        Text(exerciseType.rawValue)
                        Text("›")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.30))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            // Right icons group
            HStack(spacing: 8) {
                // Skeleton toggle
                headerIconButton(showSkeleton ? "eye.fill" : "eye.slash.fill") {
                    showSkeleton.toggle()
                    Analytics.send(Analytics.Signal.cameraSkeletonToggled, parameters: ["visible": "\(showSkeleton)"])
                }

                // Pause/Resume
                headerIconButton(isPaused ? "play.fill" : "pause.fill", tint: isPaused ? .green : nil) {
                    isPaused.toggle()
                    repCounter.isActive = !isPaused
                }

                // Tracking quality pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(trackingQuality.color)
                        .frame(width: 7, height: 7)
                        .shadow(color: trackingQuality.color.opacity(0.8), radius: 2.5)
                    Text(trackingQuality.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(trackingQuality.color)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .animation(.easeInOut(duration: 0.3), value: detectedPose?.confidence)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func headerIconButton(_ systemName: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(tint ?? Color.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
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

            // Debug metrics removed — were showing Angle/Vel/Phase/Stab/Frames overlay
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

    // Whether the set is complete (last feedback was repComplete and reps > 0)
    private var isSetComplete: Bool {
        feedback == .repComplete && repCount > 0
    }

    private var bottomControls: some View {
        VStack(spacing: 11) {
            // Set history strip
            if !loggedSets.isEmpty {
                setHistoryStrip
            }

            // Tempo display (after first rep)
            if !repCounter.completedRepMetrics.isEmpty {
                tempoRow
            }

            // Hands-free mode toggle
            handsFreeToggleRow

            // Sensitivity picker
            sensitivityPicker

            // Weight + rep adjustment row
            weightRepRow

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 22)
    }

    // MARK: - Hands-Free

    private var handsFreeToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.system(size: 13))
                .foregroundStyle(handsFreeMode ? AppColors.accent : Color.white.opacity(0.30))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("Hands-Free")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(handsFreeMode ? .white : Color.white.opacity(0.50))
                Text(handsFreeMode ? "Auto-log · rest alert · fast re-arm" : "Tap Log Set manually")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            Spacer()
            Toggle("", isOn: $handsFreeMode)
                .labelsHidden()
                .tint(AppColors.accent)
                .accessibilityIdentifier("handsFreeToggle")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(handsFreeMode ? AppColors.accent.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(handsFreeMode ? AppColors.accent.opacity(0.25) : Color.white.opacity(0.07), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.2), value: handsFreeMode)
    }

    private var autoLogCountdownOverlay: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 5)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: Double(autoLogCountdownSeconds) / 3.0)
                    .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: autoLogCountdownSeconds)
                Text("\(autoLogCountdownSeconds)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: autoLogCountdownSeconds)
            }
            Text("Logging set in \(autoLogCountdownSeconds)s")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Button {
                cancelAutoLogCountdown(andLog: false)
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color.white.opacity(0.15))
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cancelAutoLogButton")
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    private func startAutoLogCountdown() {
        autoLogCountdownSeconds = 3
        withAnimation(.spring(response: 0.3)) { showAutoLogCountdown = true }
        autoLogCountdownTimer?.invalidate()
        autoLogCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if autoLogCountdownSeconds > 1 {
                autoLogCountdownSeconds -= 1
            } else {
                cancelAutoLogCountdown(andLog: true)
            }
        }
    }

    private func cancelAutoLogCountdown(andLog: Bool) {
        autoLogCountdownTimer?.invalidate()
        autoLogCountdownTimer = nil
        withAnimation(.easeOut(duration: 0.25)) { showAutoLogCountdown = false }
        repCounter.cancelAutoLog()
        if andLog { logCurrentSet() }
    }

    private var sensitivityPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Strict", "Normal", "Easy"].enumerated()), id: \.offset) { idx, label in
                let sel = sensitivity == idx
                Button { sensitivity = idx } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(sel ? AppColors.accent : Color.white.opacity(0.30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            sel ? RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.accent.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.accent.opacity(0.30), lineWidth: 1))
                                .padding(2)
                            : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    @AppStorage("tempoDownTarget") private var tempoDownTarget: Double = 2.0
    @AppStorage("tempoUpTarget") private var tempoUpTarget: Double = 1.0

    private var tempoRow: some View {
        let lastRep = repCounter.completedRepMetrics.last!
        let downColor = tempoColor(actual: lastRep.eccentricDuration, target: tempoDownTarget)
        let upColor = tempoColor(actual: lastRep.concentricDuration, target: tempoUpTarget)
        let total = lastRep.totalDuration

        return HStack(spacing: 12) {
            Text("Tempo")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.25))
                .kerning(0.4)
                .textCase(.uppercase)

            HStack(spacing: 4) {
                Text("↓")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(downColor)
                Text(String(format: "%.1fs", lastRep.eccentricDuration))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(downColor)
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 14)

            HStack(spacing: 4) {
                Text("↑")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(upColor)
                Text(String(format: "%.1fs", lastRep.concentricDuration))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(upColor)
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 14)

            Text(String(format: "%.1fs", total))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.30))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    private func tempoColor(actual: TimeInterval, target: Double) -> Color {
        let ratio = abs(actual - target) / target
        if ratio <= 0.20 { return Color(red: 0.19, green: 0.82, blue: 0.35) }  // green
        if ratio <= 0.50 { return Color(red: 1.0, green: 0.82, blue: 0.19) }   // yellow
        return Color(red: 1.0, green: 0.23, blue: 0.19)                         // red
    }

    private var formattedWeight: String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))" : String(format: "%.1f", weight)
    }

    @State private var isEditingCameraWeight = false
    @State private var cameraWeightText = ""
    @State private var isEditingCameraReps = false
    @State private var cameraRepsText = ""

    private var weightRepRow: some View {
        HStack(spacing: 10) {
            // Weight section — half width
            VStack(spacing: 4) {
                Text("Weight (\(UnitFormatter.weightUnit))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .kerning(0.3)
                HStack(spacing: 6) {
                    bottomStepperButton("−") { weight = max(0, weight - 2.5) }
                    if isEditingCameraWeight {
                        TextField("0", text: $cameraWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 20, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .onSubmit { commitCameraWeight() }
                    } else {
                        Text(formattedWeight)
                            .font(.system(size: 20, weight: .heavy))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                cameraWeightText = formattedWeight
                                isEditingCameraWeight = true
                            }
                    }
                    bottomStepperButton("+") { weight += 2.5 }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
            )

            // Reps section — half width
            VStack(spacing: 4) {
                Text("Reps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .kerning(0.3)
                HStack(spacing: 6) {
                    repAdjustButton("−") { repCounter.removeRep(); repCount = repCounter.repCount }
                    if isEditingCameraReps {
                        TextField("0", text: $cameraRepsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 20, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .onSubmit { commitCameraReps() }
                    } else {
                        Text("\(repCount)")
                            .font(.system(size: 20, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(repCount > 0 ? feedbackColor : Color.white.opacity(0.30))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                cameraRepsText = "\(repCount)"
                                isEditingCameraReps = true
                            }
                    }
                    repAdjustButton("+") { repCounter.addRep(); repCount = repCounter.repCount }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
            )
        }
    }

    private func commitCameraWeight() {
        let clean = cameraWeightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if let v = Double(clean), v >= 0 { weight = v }
        isEditingCameraWeight = false
    }

    private func commitCameraReps() {
        if let v = Int(cameraRepsText.trimmingCharacters(in: .whitespaces)), v >= 0 {
            let delta = v - repCount
            if delta > 0 { for _ in 0..<delta { repCounter.addRep() } }
            else if delta < 0 { for _ in 0..<(-delta) { repCounter.removeRep() } }
            repCount = repCounter.repCount
        }
        isEditingCameraReps = false
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Reset
            Button {
                repCounter.reset()
                repCount = 0
            } label: {
                Text("Reset")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.13), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            // Log Set — green when complete, coral when counting, gray when disabled
            Button { logCurrentSet() } label: {
                HStack(spacing: 8) {
                    Text("✓")
                        .font(.system(size: 14, weight: .heavy))
                    Text(loggedSets.isEmpty ? "Log Set" : "Log Set \(loggedSets.count + 1)")
                        .font(.system(size: 14, weight: .heavy))
                        .kerning(0.4)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(logButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: logButtonShadowColor, radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(repCount == 0)
        }
    }

    private var logButtonGradient: some ShapeStyle {
        if repCount == 0 {
            return AnyShapeStyle(Color.white.opacity(0.08))
        } else if isSetComplete {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.20, green: 0.82, blue: 0.37), Color(red: 0.13, green: 0.63, blue: 0.25)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [AppColors.accent, Color(red: 0.75, green: 0.14, blue: 0.23)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
    }

    private var logButtonShadowColor: Color {
        if repCount == 0 { return .clear }
        return isSetComplete ? Color.green.opacity(0.35) : AppColors.accent.opacity(0.35)
    }

    private func bottomStepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func repAdjustButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
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

        // Compute average tempo from completed rep metrics
        let metrics = repCounter.completedRepMetrics
        let avgDown: Double? = metrics.isEmpty ? nil : metrics.map(\.eccentricDuration).reduce(0, +) / Double(metrics.count)
        let avgUp: Double? = metrics.isEmpty ? nil : metrics.map(\.concentricDuration).reduce(0, +) / Double(metrics.count)

        // Save set immediately (convert display value back to storage units — always lbs internally)
        onSetLogged(repCount, UnitFormatter.convertToStorage(weight), avgDown, avgUp)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Analytics.send(Analytics.Signal.cameraSetLogged, parameters: [
            "exerciseName": exerciseName,
            "reps": "\(repCount)",
            "weight": "\(weight)"
        ])

        // Track for history display
        loggedSets.append((reps: repCount, weight: weight, rejectedShallow: shallowCount, rejectedFast: fastCount))

        // Queue peak frame for end-of-exercise gallery (instead of interrupting mid-workout)
        var frame = peakContractionFrame
        #if targetEnvironment(simulator)
        // TEMP: Simulator has no camera — generate a placeholder frame for UI testing
        if frame == nil {
            let hues: [CGFloat] = [0.6, 0.75, 0.85, 0.55, 0.45]
            let hue = hues[loggedSets.count % hues.count]
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
            frame = renderer.image { ctx in
                UIColor(hue: hue, saturation: 0.4, brightness: 0.25, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            }
        }
        #endif
        if let frame {
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
            capturedFrames.append((config: config, setNumber: loggedSets.count))
        }
        peakContractionFrame = nil

        // Show confirmation
        withAnimation(.spring(response: 0.3)) {
            showSetLoggedConfirmation = true
        }

        // Reset for next set
        repCounter.reset()
        repCount = 0

        // Auto-hide confirmation after 1.5s, then start rest timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSetLoggedConfirmation = false
            }
            // Start rest timer if enabled globally or in hands-free mode
            if cameraRestEnabled || handsFreeMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startCameraRest()
                }
            }
        }
    }

    // MARK: - Camera Rest Timer

    private func startCameraRest() {
        restTotalSeconds = cameraRestDuration
        restSecondsRemaining = cameraRestDuration
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isResting = true
        }
        // Pause rep detection during rest
        repCounter.isActive = false

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if restSecondsRemaining > 0 {
                restSecondsRemaining -= 1
            } else {
                endCameraRest()
            }
        }
    }

    private func endCameraRest() {
        restTimer?.invalidate()
        restTimer = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isResting = false
        }
        // Re-activate rep detection
        repCounter.isActive = true

        if handsFreeMode {
            // Pre-arm: shorter stability window so user is "Ready" almost instantly
            repCounter.reducedArmingWindow = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Audible chime — works when phone is propped at gym distance
            AudioServicesPlaySystemSound(1057)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func addRestTime(_ seconds: Int) {
        restSecondsRemaining += seconds
        restTotalSeconds += seconds
    }

    private var restProgress: Double {
        guard restTotalSeconds > 0 else { return 0 }
        return Double(restTotalSeconds - restSecondsRemaining) / Double(restTotalSeconds)
    }

    private var formattedRestTime: String {
        let m = restSecondsRemaining / 60
        let s = restSecondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Camera Rest Overlay (gold ring on camera feed)

    private var cameraRestOverlay: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(AppColors.accentGold.opacity(0.12), lineWidth: 6)
                    .frame(width: 110, height: 110)
                // Progress ring
                Circle()
                    .trim(from: 0, to: restProgress)
                    .stroke(AppColors.accentGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AppColors.accentGold.opacity(0.4), radius: 4)
                    .animation(.linear(duration: 1.0), value: restProgress)
                // Time + label
                VStack(spacing: 2) {
                    Text(formattedRestTime)
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("Resting")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            Text("Set \(loggedSets.count + 1) next")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accentGold.opacity(0.6))
        }
    }

    private var cameraRestBottomPanel: some View {
        VStack(spacing: 12) {
            // Set history
            if !loggedSets.isEmpty {
                setHistoryStrip
            }

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    addRestTime(30)
                } label: {
                    Text("+ 30s")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.accentGold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(AppColors.accentGold.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppColors.accentGold.opacity(0.25), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    endCameraRest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Skip")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.13), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 22)
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
        #if targetEnvironment(simulator)
        // Simulator has no camera hardware — skip permission check and use video feed
        cameraPermission = .authorized
        #else
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
        #endif
    }
}

// MARK: - Frame Gallery (End of Exercise)

/// Shows all captured peak frames from the camera session. User picks one to share or skips all.
private struct FrameGalleryView: View {
    let frames: [(config: ShareCardConfig, setNumber: Int)]
    var onSelect: (ShareCardConfig) -> Void
    var onSkipAll: () -> Void

    @State private var currentPage = 0

    // Gradient palettes that shift per page
    private static let palettes: [[Color]] = [
        [Color(red: 0.18, green: 0.08, blue: 0.35), Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.30, green: 0.10, blue: 0.12)],
        [Color(red: 0.05, green: 0.12, blue: 0.30), Color(red: 0.04, green: 0.04, blue: 0.12), Color(red: 0.10, green: 0.25, blue: 0.30)],
        [Color(red: 0.25, green: 0.08, blue: 0.10), Color(red: 0.06, green: 0.04, blue: 0.10), Color(red: 0.30, green: 0.18, blue: 0.05)],
    ]

    private var pal: [Color] { Self.palettes[currentPage % Self.palettes.count] }
    private let dark = Color(red: 0.04, green: 0.04, blue: 0.08)

    var body: some View {
        ZStack {
            // Vibrant mesh gradient background
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    pal[0], pal[1], pal[2],
                    pal[1], dark,   pal[0],
                    pal[2], pal[0], pal[1]
                ]
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentPage)

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Button(action: onSkipAll) {
                        Text("Skip")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Your Highlights")
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(frames.count) shot\(frames.count == 1 ? "" : "s") captured")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    // Invisible balance for centering
                    Text("Skip")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.clear)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Frame carousel
                TabView(selection: $currentPage) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { index, entry in
                        frameCard(entry: entry)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Bottom area
                VStack(spacing: 10) {
                    // Share CTA
                    Button {
                        guard currentPage < frames.count else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSelect(frames[currentPage].config)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share This Shot")
                                .font(.system(.body, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .gradientCTA(cornerRadius: 14)
                    }

                    // Custom page dots
                    HStack(spacing: 6) {
                        ForEach(0..<frames.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.white.opacity(0.8) : Color.white.opacity(0.2))
                                .frame(width: i == currentPage ? 18 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.25), value: currentPage)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if let prIndex = frames.firstIndex(where: { $0.config.isPR }) {
                currentPage = prIndex
            }
        }
    }

    @ViewBuilder
    private func frameCard(entry: (config: ShareCardConfig, setNumber: Int)) -> some View {
        VStack(spacing: 14) {
            // Frame image with overlaid metadata
            ZStack(alignment: .bottom) {
                Image(uiImage: entry.config.photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .scaleEffect(x: entry.config.isPhotoFlipped ? -1 : 1, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 15)

                // Frosted stats overlay at bottom of image
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SET \(entry.setNumber + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(1.5)
                        Text("\(entry.config.reps) × \(Int(entry.config.weight)) \(entry.config.weightUnit)")
                            .font(.system(.title2, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if entry.config.isPR {
                        HStack(spacing: 5) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12))
                            Text("PR")
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundStyle(AppColors.accentGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 20,
                            bottomTrailingRadius: 20,
                            topTrailingRadius: 0
                        )
                    )
                )
            }

            // Exercise name
            Text(entry.config.exerciseName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.5)
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Share Card Editor

/// Self-contained share card editor sheet.
/// Owns all picker state so parent re-renders cannot accidentally dismiss open pickers.
private struct ShareCardEditorView: View {
    @Binding var config: ShareCardConfig
    var onSkip: () -> Void
    var onShare: (UIImage) -> Void

    @Environment(ProManager.self) private var proManager

    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var useFrontCamera = false
    @State private var thumbnails: [CardTheme: UIImage] = [:]
    @State private var backgroundSwatches: [CardBackground: UIImage] = [:]
    @State private var isRendering = false
    @State private var showSavedToast = false

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
                VStack(spacing: 14) {
                    // Live interactive preview
                    CardLivePreview(config: $config)
                        .padding(.horizontal, 60)

                    // Inline photo swap row
                    photoSwapRow

                    // Filter thumbnail strip
                    editorSectionLabel("Film Style")
                    filterStripView

                    // Background picker
                    editorSectionLabel("Background")
                    backgroundPickerRow

                    // Stat toggle chips
                    editorSectionLabel("Stats to Show")
                    statToggleRow

                    // Skip / Save / Share buttons
                    HStack(spacing: 10) {
                        Button("Skip") { onSkip() }
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Save to Photos — free, doesn't consume share card quota
                        Button {
                            renderAsync { card in
                                UIImageWriteToSavedPhotosAlbum(card, nil, nil, nil)
                                Analytics.send(Analytics.Signal.shareCardSaved, parameters: [
                                    "theme": config.theme.rawValue,
                                    "isPR": "\(config.isPR)"
                                ])
                                withAnimation(.spring(response: 0.3)) { showSavedToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeOut) { showSavedToast = false }
                                }
                            }
                        } label: {
                            ZStack {
                                Label("Save", systemImage: "arrow.down.to.line")
                                    .opacity(isRendering ? 0 : 1)
                                if isRendering { ProgressView().tint(AppColors.accent) }
                            }
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accent.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isRendering)

                        // Share — consumes a share card quota slot
                        Button {
                            renderAsync { card in
                                Analytics.send(Analytics.Signal.shareCardShared, parameters: [
                                    "theme": config.theme.rawValue,
                                    "background": config.background.rawValue,
                                    "isPR": "\(config.isPR)"
                                ])
                                onShare(card)
                            }
                        } label: {
                            ZStack {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .opacity(isRendering ? 0 : 1)
                                if isRendering { ProgressView().tint(.white) }
                            }
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .gradientCTA(height: 48, cornerRadius: 12)
                            .opacity(isRendering ? 0.7 : 1.0)
                        }
                        .disabled(isRendering)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 16)
            }
            .background(
                ZStack {
                    AppColors.background
                    // Subtle gradient glow
                    RadialGradient(
                        colors: [AppColors.accent.opacity(0.08), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 400
                    )
                    RadialGradient(
                        colors: [AppColors.accentBlue.opacity(0.06), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 400
                    )
                }
                .ignoresSafeArea()
            )
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Saved to Photos")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 8)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: showSavedToast)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Share Your Set").font(.headline)
                        if !proManager.isPro {
                            let n = proManager.shareCardsRemaining
                            Text("\(n) card\(n == 1 ? "" : "s") left this month")
                                .font(.caption2)
                                .foregroundStyle(n <= 1 ? Color.red : Color.secondary)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateThumbnails()
                Analytics.send(Analytics.Signal.shareCardCreated, parameters: [
                    "theme": config.theme.rawValue,
                    "background": config.background.rawValue,
                    "isPR": "\(config.isPR)"
                ])
            }
            .onChange(of: config.photo) { _, _ in generateThumbnails() }
            .onChange(of: config.theme) { _, _ in generateBackgroundSwatches() }
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

    // MARK: - Photo Swap Row

    private var photoSwapRow: some View {
        HStack(spacing: 8) {
            photoSwapButton(icon: "camera.fill", label: "Camera") {
                useFrontCamera = false
                showCameraPicker = true
            }
            photoSwapButton(icon: "person.fill", label: "Selfie") {
                useFrontCamera = true
                showCameraPicker = true
            }
            photoSwapButton(icon: "photo.fill", label: "Library") {
                showPhotoPicker = true
            }
            photoSwapButton(icon: "arrow.counterclockwise", label: "Reset") {
                config.photo = originalPhoto
                config.isPhotoFlipped = originalIsFlipped
                config.photoScale = 1.0
                config.photoOffset = .zero
                config.statsOffset = .zero
                config.statsScale = 1.0
            }
        }
        .padding(.horizontal)
    }

    private func photoSwapButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white.opacity(0.65))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Async Render Helper

    /// Renders the card off the main thread, then calls `completion` on MainActor with the result.
    private func renderAsync(completion: @escaping (UIImage) -> Void) {
        guard !isRendering else { return }
        isRendering = true
        let capturedConfig = config
        Task.detached(priority: .userInitiated) {
            let card = WorkoutCardRenderer.render(config: capturedConfig)
            await MainActor.run {
                isRendering = false
                if let card { completion(card) }
            }
        }
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

    // MARK: - Section Label

    private func editorSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.25))
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
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
            } else if config.background == .sunset {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.55, blue: 0.20),
                        Color(red: 0.90, green: 0.35, blue: 0.40),
                        Color(red: 0.55, green: 0.25, blue: 0.55),
                        Color(red: 0.25, green: 0.15, blue: 0.40)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if config.background == .lavender {
                LinearGradient(
                    colors: [
                        Color(red: 0.72, green: 0.58, blue: 0.82),
                        Color(red: 0.85, green: 0.65, blue: 0.78),
                        Color(red: 0.92, green: 0.75, blue: 0.68),
                        Color(red: 0.78, green: 0.62, blue: 0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if config.background == .ember {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.65, blue: 0.15),
                        Color(red: 0.95, green: 0.35, blue: 0.15),
                        Color(red: 0.70, green: 0.12, blue: 0.20),
                        Color(red: 0.35, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
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

// MARK: - Previews

#Preview("Camera") {
    CameraRepCounterView(
        exerciseName: "Squat",
        lastWeight: 135,
        onSetLogged: { reps, weight, _, _ in
            debugLog("Logged: \(reps) reps @ \(weight) lbs")
        }
    )
}

private func makePreviewFrames() -> [(config: ShareCardConfig, setNumber: Int)] {
    let repsPerSet = [8, 8, 6]
    let colors: [UIColor] = [.darkGray, .systemIndigo, .systemTeal]
    var result: [(config: ShareCardConfig, setNumber: Int)] = []

    for i in 0..<3 {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        let color = colors[i]
        let img = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
        }
        let config = ShareCardConfig(
            photo: img,
            exerciseName: "Bench Press",
            reps: repsPerSet[i],
            weight: 185,
            weightUnit: "lbs",
            estimated1RM: 234,
            isPR: i == 2
        )
        result.append((config: config, setNumber: i))
    }
    return result
}

#Preview("Frame Gallery") {
    FrameGalleryView(
        frames: makePreviewFrames(),
        onSelect: { _ in },
        onSkipAll: { }
    )
}
