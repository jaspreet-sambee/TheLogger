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
    @State private var feedback: RepCounter.MovementFeedback = .ready
    @State private var detectedPose: DetectedPose?
    @State private var selectedExerciseType: ExerciseType
    @State private var showExercisePicker = false
    @State private var isPaused = false

    // Camera permission
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined

    // Skeleton toggle
    @AppStorage("showSkeletonOverlay") private var showSkeleton = true

    // Calibration overlay
    @State private var showCalibrationOverlay = true
    @State private var calibrationDismissed = false

    // Phone orientation warning
    @State private var isTooFlat = false

    // Exercise auto-detection
    @State private var exerciseAutoDetected: Bool

    // Rep counter (needs to persist during view updates)
    @State private var repCounter: RepCounter

    // Computed
    private var exerciseType: ExerciseType {
        selectedExerciseType
    }

    private var feedbackColor: Color {
        switch feedback {
        case .ready: return .white.opacity(0.7)
        case .goingDown, .goingUp: return .yellow
        case .holdingDown: return AppColors.accent
        case .repComplete: return .green
        case .noDetection: return .red.opacity(0.7)
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

        // Initialize weight
        self._weight = State(initialValue: lastWeight)

        // Determine exercise type
        let detectedType = ExerciseType.from(exerciseName: exerciseName)
        self._exerciseAutoDetected = State(initialValue: detectedType != nil)
        let exerciseType = detectedType ?? .squat
        self._selectedExerciseType = State(initialValue: exerciseType)
        self._repCounter = State(initialValue: RepCounter(exerciseType: exerciseType))
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
                    isTooFlat: $isTooFlat
                )
                .ignoresSafeArea()
            } else {
                // Paused state
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

            // UI Overlay
            VStack(spacing: 0) {
                // Header
                headerView
                    .background(.ultraThinMaterial.opacity(0.8))

                // Phone too flat warning (non-dismissible, auto-clears when repositioned)
                if isTooFlat {
                    tooFlatWarningView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Rep counter display
                repCounterDisplay

                Spacer()

                // Feedback indicator
                feedbackView
                    .padding(.bottom, 20)

                // Bottom controls
                bottomControls
                    .background(.ultraThinMaterial.opacity(0.9))
            }

            // Calibration overlay
            if showCalibrationOverlay && !calibrationDismissed && !isPaused {
                calibrationOverlayView
                    .transition(.opacity)
            }
        }
        .onChange(of: selectedExerciseType) { _, newType in
            repCounter.reset()
            repCount = 0
        }
        .onChange(of: detectedPose?.confidence) { _, newConfidence in
            // Auto-dismiss calibration when good tracking detected
            if let confidence = newConfidence, confidence > 0.7, showCalibrationOverlay {
                withAnimation(.easeOut(duration: 0.4)) {
                    showCalibrationOverlay = false
                    calibrationDismissed = true
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            // Auto-open exercise picker for unsupported exercises
            if !exerciseAutoDetected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showExercisePicker = true
                }
            }
            // Auto-dismiss calibration after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if showCalibrationOverlay {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showCalibrationOverlay = false
                        calibrationDismissed = true
                    }
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

            VStack(spacing: 24) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 100, weight: .thin))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Position Yourself")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Stand back so the camera can see your full body")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Per-exercise phone placement tip
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
                .padding(.horizontal, 40)

                // Tracking note chip
                Label(exerciseType.trackingNote, systemImage: "arrow.left.arrow.right")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }
        }
        .allowsHitTesting(false)
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
            Text("\(repCount)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 10)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: repCount)

            Text("REPS")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(4)

            // Debug info (angle)
            #if DEBUG
            Text("Angle: \(Int(currentAngle))°")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 8)
            #endif
        }
    }

    private var feedbackView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(feedbackColor)
                .frame(width: 10, height: 10)

            Text(feedback.rawValue)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(feedbackColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
        )
        .animation(.easeInOut(duration: 0.2), value: feedback)
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
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

                Text("lbs")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                // Manual rep adjustment
                HStack(spacing: 8) {
                    Button {
                        if repCount > 0 {
                            repCount -= 1
                            repCounter.reset()
                            for _ in 0..<repCount {
                                repCounter.addRep()
                            }
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Button {
                        repCount += 1
                        repCounter.addRep()
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

                // Log set button
                Button {
                    onSetLogged(repCount, weight)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log Set")
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

    // MARK: - Exercise Picker Sheet

    private var exercisePickerSheet: some View {
        NavigationStack {
            List {
                // Banner for unsupported exercises
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
            print("Logged: \(reps) reps @ \(weight) lbs")
        }
    )
}
