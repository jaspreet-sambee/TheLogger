//
//  SummaryViews.swift
//  TheLogger
//
//  Workout summary and exercise progress views
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Workout End Summary View

/// Summary shown after ending a workout. Requires ~2s before Done is tappable.
struct WorkoutEndSummaryView: View {
    let summary: WorkoutSummary
    let workoutName: String
    let workoutDate: Date
    let prExercises: [String]
    let prDetails: [(name: String, weight: Double, reps: Int)]
    let onDismiss: () -> Void

    init(
        summary: WorkoutSummary,
        workoutName: String = "",
        workoutDate: Date = Date(),
        prExercises: [String] = [],
        prDetails: [(name: String, weight: Double, reps: Int)] = [],
        onDismiss: @escaping () -> Void
    ) {
        self.summary = summary
        self.workoutName = workoutName
        self.workoutDate = workoutDate
        self.prExercises = prExercises
        self.prDetails = prDetails
        self.onDismiss = onDismiss
    }

    @State private var affirmation = "Nice work"
    @State private var showHeader = false
    @State private var showAffirmation = false
    @State private var showDuration = false
    @State private var showStats = false
    @State private var showPRs = false
    @State private var showButton = false
    @State private var canDismiss = false
    @State private var showConfetti = false
    @State private var prRowsRevealed = 0
    @State private var durationPulse = false
    @State private var medalBounce = false
    @State private var showSummaryEditor = false
    @Environment(ProManager.self) private var proManager
    private let minDisplaySeconds: Double = 1.0

    private static let workoutDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var hasPRs: Bool { !prExercises.isEmpty }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                        .opacity(showHeader ? 1 : 0)
                        .offset(y: showHeader ? 0 : 8)
                        .animation(.easeOut(duration: 0.32), value: showHeader)

                    affirmationText
                        .opacity(showAffirmation ? 1 : 0)
                        .offset(y: showAffirmation ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showAffirmation)

                    prSection
                        .opacity(showPRs ? 1 : 0)
                        .offset(y: showPRs ? 0 : 12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showPRs)

                    durationStat
                        .opacity(showDuration ? 1 : 0)
                        .offset(y: showDuration ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showDuration)

                    secondaryStats
                        .opacity(showStats ? 1 : 0)
                        .offset(y: showStats ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showStats)

                    dismissButton
                        .opacity(showButton ? 1 : 0)
                        .offset(y: showButton ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showButton)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .onAppear {
                Analytics.send(Analytics.Signal.workoutSummaryViewed)
                let options = ["Nice work", "Well done", "Great session", "Solid effort", "Keep it up"]
                affirmation = options.randomElement() ?? "Nice work"

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                if !prExercises.isEmpty {
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showConfetti = false
                    }
                }
                scheduleStagger()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    medalBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    durationPulse = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + minDisplaySeconds) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        canDismiss = true
                    }
                }
            }

            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    private func scheduleStagger() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { showHeader = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { showAffirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showPRs = true
            for i in 0..<prDetails.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    prRowsRevealed = i + 1
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { showDuration = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showStats = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) { showButton = true }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentGold.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(AppColors.accentGold.opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: AppColors.accentGold.opacity(0.3), radius: 20, y: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.accentGold)
            }

            if !workoutName.isEmpty {
                Text(workoutName)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            Text(Self.workoutDateFormatter.string(from: workoutDate))
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var affirmationText: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.accentGold.opacity(0.9))
            Text(affirmation)
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private var durationStat: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.9))
                Text(summary.formattedDuration)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .scaleEffect(durationPulse ? 1 : 0.97)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65), value: durationPulse)
            }
            Text("workout time")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppColors.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var secondaryStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            statGridCell(value: summary.formattedDuration, label: "duration", isHighlight: true)
            statGridCell(value: summary.totalVolume > 0 ? summary.formattedVolume : "—", label: "volume", isHighlight: false)
            statGridCell(value: "\(summary.totalExercises)", label: "exercises", isHighlight: false)
            statGridCell(value: "\(summary.totalSets)", label: "sets", isHighlight: false)
        }
    }

    private func statGridCell(value: String, label: String, isHighlight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(isHighlight ? AppColors.accent : Color.white.opacity(0.85))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighlight ? AppColors.accent.opacity(0.06) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHighlight ? AppColors.accent.opacity(0.20) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var prSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(hasPRs ? AppColors.accentGold : .secondary.opacity(0.7))
                    .symbolEffect(.bounce, value: medalBounce)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasPRs ? "PRs achieved this workout" : "Personal Records")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.primary)
                    if prDetails.count > 1 {
                        Text("\(prDetails.count) new records")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if prDetails.isEmpty && prExercises.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "flame")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.accent.opacity(0.8))
                    Text("No PRs this workout — keep pushing!")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if prDetails.isEmpty {
                Text(prExercises.joined(separator: ", "))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(prDetails.enumerated()), id: \.element.name) { index, item in
                        HStack(spacing: 10) {
                            Text(item.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formatPR(item))
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(AppColors.accent)
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.accentGold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accentGold.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.accentGold.opacity(0.22), lineWidth: 1)
                                )
                        )
                        .opacity(index < prRowsRevealed ? 1 : 0)
                        .offset(y: index < prRowsRevealed ? 0 : 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: prRowsRevealed)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            hasPRs
                                ? LinearGradient(
                                    colors: [AppColors.accentGold.opacity(0.10), AppColors.accent.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.04), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    hasPRs ? AppColors.accentGold.opacity(0.35) : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
        )
    }

    private func formatPR(_ item: (name: String, weight: Double, reps: Int)) -> String {
        if item.weight > 0 {
            return "\(UnitFormatter.formatWeight(item.weight, showUnit: false)) × \(item.reps)"
        }
        return "BW × \(item.reps)"
    }

    private var dismissButton: some View {
        VStack(spacing: 10) {
            if canDismiss && proManager.canUseShareCard {
                Button {
                    showSummaryEditor = true
                } label: {
                    Label("Share Workout", systemImage: "square.and.arrow.up")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button {
                Analytics.send(Analytics.Signal.workoutSummaryDismissed)
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    if canDismiss {
                        Text("Done")
                    } else {
                        ProgressView()
                            .tint(.white)
                        Text("Viewing summary...")
                            .font(.system(.subheadline, weight: .medium))
                    }
                }
            }
            .gradientCTA()
            .opacity(canDismiss ? 1 : 0.55)
            .disabled(!canDismiss)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showSummaryEditor) {
            let summaryConfig = WorkoutSummaryConfig(
                workoutName: workoutName,
                date: workoutDate,
                duration: summary.duration,
                totalExercises: summary.totalExercises,
                totalSets: summary.totalSets,
                totalVolume: UnitFormatter.convertToDisplay(summary.totalVolume),
                weightUnit: UnitFormatter.weightUnit,
                prCount: prExercises.count,
                prExercises: Array(prExercises.prefix(3))
            )
            WorkoutSummaryEditorView(
                config: summaryConfig,
                onSkip: { showSummaryEditor = false },
                onShare: { card in
                    proManager.recordShareCard()
                    let activityVC = UIActivityViewController(
                        activityItems: [card],
                        applicationActivities: nil
                    )
                    activityVC.completionWithItemsHandler = { _, _, _, _ in
                        showSummaryEditor = false
                    }
                    // Present from the topmost VC (the sheet itself), not root —
                    // root.present fails silently while the sheet is still alive.
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = windowScene.windows.first?.rootViewController {
                        var top = root
                        while let next = top.presentedViewController { top = next }
                        top.present(activityVC, animated: true)
                    }
                }
            )
        }
    }

}

// MARK: - Workout Summary Card Editor

/// Sheet for editing and sharing the end-of-workout summary card.
/// 1:1 square card, Strava-style: full-bleed photo + gradient fade + stats overlay.
private struct WorkoutSummaryEditorView: View {
    let config: WorkoutSummaryConfig
    var onSkip: () -> Void
    var onShare: (UIImage) -> Void

    @State private var theme: CardTheme = .cinematic
    @State private var statsPosition: StatsPosition = .top
    @State private var photo: UIImage? = nil
    @State private var isPhotoFlipped: Bool = false
    @State private var photoScale: CGFloat = 1.0
    @State private var photoOffset: CGPoint = .zero
    @State private var showReplacePhotoOptions = false
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var useFrontCamera = false

    private var liveConfig: WorkoutSummaryConfig {
        var cfg = config
        cfg.theme = theme
        cfg.photo = photo
        cfg.isPhotoFlipped = isPhotoFlipped
        cfg.photoScale = photoScale
        cfg.photoOffset = photoOffset
        cfg.statsPosition = statsPosition
        return cfg
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live card preview with pinch-to-zoom
                    WorkoutSummaryLivePreview(
                        config: liveConfig,
                        photoScale: $photoScale,
                        photoOffset: $photoOffset
                    )
                    .padding(.horizontal, 32)
                    .overlay(alignment: .topTrailing) {
                        Button { showReplacePhotoOptions = true } label: {
                            Image(systemName: photo == nil ? "camera.fill" : "camera.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.top, 4)
                        .padding(.trailing, 36)
                    }

                    // Stats position toggle
                    Picker("Stats position", selection: $statsPosition) {
                        Text("Stats Top").tag(StatsPosition.top)
                        Text("Stats Bottom").tag(StatsPosition.bottom)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Theme picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(CardTheme.allCases, id: \.self) { t in
                                Button {
                                    theme = t
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(t.accentSwiftUI)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle().stroke(Color.white, lineWidth: theme == t ? 2 : 0)
                                            )
                                            .shadow(color: t.accentSwiftUI.opacity(0.5), radius: theme == t ? 6 : 0)
                                        Text(t.displayName)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(theme == t ? t.accentSwiftUI : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                    }

                    // Skip / Share
                    HStack(spacing: 12) {
                        Button("Skip") { onSkip() }
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            if let card = WorkoutSummaryCardRenderer.render(config: liveConfig) {
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
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationBackground(AppColors.background)
        .confirmationDialog("Add Photo", isPresented: $showReplacePhotoOptions) {
            Button("Take Photo") { useFrontCamera = false; showCameraPicker = true }
            Button("Take Selfie") { useFrontCamera = true; showCameraPicker = true }
            Button("Choose from Library") { showPhotoPicker = true }
            if photo != nil {
                Button("Remove Photo", role: .destructive) {
                    photo = nil
                    isPhotoFlipped = false
                    photoScale = 1.0
                    photoOffset = .zero
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(
                selectedImage: Binding(
                    get: { nil },
                    set: { img in
                        if let img {
                            photo = img
                            isPhotoFlipped = false
                            photoScale = 1.0
                            photoOffset = .zero
                        }
                    }
                ),
                onDismiss: {}
            )
        }
        .sheet(isPresented: $showCameraPicker) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraPickerView(cameraDevice: useFrontCamera ? .front : .rear) { img in
                    photo = img.normalizedOrientation()
                    isPhotoFlipped = useFrontCamera
                    photoScale = 1.0
                    photoOffset = .zero
                }
            }
        }
    }
}

// MARK: - Workout Summary Live Preview

/// Interactive 1:1 preview of the workout share card.
/// Pinch-to-zoom and drag reposition the photo; stats/gradient are SwiftUI approximations.
/// Final share uses WorkoutSummaryCardRenderer.render(config:) for pixel-perfect output.
private struct WorkoutSummaryLivePreview: View {
    let config: WorkoutSummaryConfig
    @Binding var photoScale: CGFloat
    @Binding var photoOffset: CGPoint

    @GestureState private var pinchDelta: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero
    @State private var displayPhoto: UIImage? = nil

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        return fmt.string(from: config.date)
    }

    private func refreshDisplayPhoto() {
        guard let photo = config.photo else { displayPhoto = nil; return }
        let src = config.isPhotoFlipped ? photo.flippedHorizontally() : photo
        displayPhoto = src.scaledDown(toMaxDimension: 1200)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let sx = w / 1080

            ZStack(alignment: .topLeading) {
                if let dp = displayPhoto {
                    photoLayer(photo: dp, w: w, sx: sx)
                } else if config.photo == nil {
                    darkBackground(w: w)
                }
                gradientOverlay(w: w)
                    .allowsHitTesting(false)
                statsOverlay(w: w, sx: sx)
                    .allowsHitTesting(false)
            }
            .frame(width: w, height: w)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .bottomTrailing) {
            Text("TheLogger")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.40))
                .padding(.trailing, 14)
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .onAppear { refreshDisplayPhoto() }
        .onChange(of: config.photo) { _, _ in refreshDisplayPhoto() }
        .onChange(of: config.isPhotoFlipped) { _, _ in refreshDisplayPhoto() }
    }

    @ViewBuilder
    private func photoLayer(photo: UIImage, w: CGFloat, sx: CGFloat) -> some View {
        let displayScale = photoScale * pinchDelta
        let displayOffsetX = photoOffset.x * sx + dragDelta.width
        let displayOffsetY = photoOffset.y * sx + dragDelta.height

        Image(uiImage: photo)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: w, height: w)
            .scaleEffect(displayScale)
            .offset(x: displayOffsetX, y: displayOffsetY)
            .clipped()
            .gesture(
                MagnificationGesture()
                    .updating($pinchDelta) { val, state, _ in state = val }
                    .onEnded { val in
                        photoScale = max(1.0, min(5.0, photoScale * val))
                    }
                    .simultaneously(with:
                        DragGesture()
                            .updating($dragDelta) { val, state, _ in state = val.translation }
                            .onEnded { val in
                                photoOffset = CGPoint(
                                    x: photoOffset.x + val.translation.width / sx,
                                    y: photoOffset.y + val.translation.height / sx
                                )
                            }
                    )
            )
    }

    @ViewBuilder
    private func darkBackground(w: CGFloat) -> some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [config.theme.accentSwiftUI.opacity(0.50), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: w * 0.74
            )
        }
        .frame(width: w, height: w)
    }

    @ViewBuilder
    private func gradientOverlay(w: CGFloat) -> some View {
        switch config.statsPosition {
        case .top:
            VStack(spacing: 0) {
                Color.black.opacity(0.65).frame(height: w * 0.288)
                LinearGradient(colors: [.black.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: w * 0.119)
                Spacer(minLength: 0)
            }
            .frame(width: w, height: w)
        case .bottom:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                    .frame(height: w * 0.056)
                Color.black.opacity(0.65).frame(height: w * 0.398)
            }
            .frame(width: w, height: w)
        }
    }

    @ViewBuilder
    private func statsOverlay(w: CGFloat, sx: CGFloat) -> some View {
        let nameY: CGFloat = config.statsPosition == .top ? 50 * sx : 660 * sx
        let accent = config.theme.accentSwiftUI
        let stats = buildStatsItems()

        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: nameY)

            // Workout name + PR badge
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(config.workoutName)
                    .font(.system(size: 64 * sx, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if config.prCount > 0 {
                    Text("🏆 \(config.prCount) PR\(config.prCount == 1 ? "" : "s")")
                        .font(.system(size: 26 * sx, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.07))
                        .padding(.horizontal, 16 * sx)
                        .padding(.vertical, 8 * sx)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14 * sx))
                }
            }
            .frame(width: w - 120 * sx)
            .padding(.leading, 60 * sx)

            // Date
            Text(formattedDate)
                .font(.system(size: 30 * sx, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 60 * sx)
                .padding(.top, 4 * sx)

            // Accent separator
            accent.opacity(0.55)
                .frame(width: 160 * sx, height: 3 * sx)
                .clipShape(RoundedRectangle(cornerRadius: 1.5 * sx))
                .padding(.leading, 60 * sx)
                .padding(.top, 18 * sx)

            // Stats row
            HStack(alignment: .top, spacing: 12 * sx) {
                ForEach(stats, id: \.label) { stat in
                    VStack(alignment: .leading, spacing: 6 * sx) {
                        Text(stat.value)
                            .font(.system(size: 48 * sx, weight: .bold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(stat.label)
                            .font(.system(size: 22 * sx, weight: .regular))
                            .foregroundStyle(.white.opacity(0.50))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: w - 120 * sx)
            .padding(.leading, 60 * sx)
            .padding(.top, 28 * sx)
        }
    }

    private func buildStatsItems() -> [(value: String, label: String)] {
        var items: [(value: String, label: String)] = []
        if let dur = config.duration {
            let m = Int(dur) / 60, s = Int(dur) % 60
            items.append((m > 0 ? "\(m)m \(s)s" : "\(s)s", "time"))
        }
        items.append(("\(config.totalExercises)", "exercises"))
        items.append(("\(config.totalSets)", "sets"))
        if config.totalVolume > 0 {
            let vol = config.totalVolume >= 1000
                ? String(format: "%.1fk", config.totalVolume / 1000) + " \(config.weightUnit)"
                : "\(Int(config.totalVolume)) \(config.weightUnit)"
            items.append((vol, "volume"))
        }
        return items
    }
}

// MARK: - Exercise Progress View

struct ExerciseProgressView: View {
    let exerciseName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var emptyChartAppeared = false
    @State private var cachedProgressData: [WeightDataPoint] = []

    struct WeightDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
    }

    private func loadProgressData() {
        guard cachedProgressData.isEmpty else { return }
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: CharacterSet.whitespaces)
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.date, order: .forward)])
        guard let workouts = try? modelContext.fetch(descriptor) else { return }
        var dataPoints: [WeightDataPoint] = []
        for workout in workouts where workout.endTime != nil && !workout.isTemplate {
            if let exercise = workout.exercises?.first(where: { $0.name.lowercased().trimmingCharacters(in: CharacterSet.whitespaces) == normalizedName }) {
                let maxWeight = (exercise.sets ?? []).map { $0.weight }.max() ?? 0
                if maxWeight > 0 {
                    dataPoints.append(WeightDataPoint(date: workout.date, maxWeight: maxWeight))
                }
            }
        }
        cachedProgressData = dataPoints
    }

    private var maxWeightEver: Double { cachedProgressData.map { $0.maxWeight }.max() ?? 0 }
    private var lastPerformed: Date? { cachedProgressData.last?.date }
    private var formattedLastPerformed: String {
        guard let date = lastPerformed else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statsSection
                    if cachedProgressData.count >= 2 { chartSection } else { emptyChartState }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(AppColors.background)
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadProgressData() }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(title: "Max Weight", value: maxWeightEver > 0 ? String(format: "%.0f", UnitFormatter.convertToDisplay(maxWeightEver)) : "--", unit: UnitFormatter.weightUnit, icon: "arrow.up.circle.fill", color: AppColors.accent)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Last Performed")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(formattedLastPerformed)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            )
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
        )
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Over Time")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            Chart(cachedProgressData) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(LinearGradient(colors: AppColors.accentGradient, startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                AreaMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(LinearGradient(colors: [AppColors.accent.opacity(0.2), AppColors.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                PointMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(AppColors.accent)
                    .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .frame(height: 200)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accent.opacity(0.25), lineWidth: 1))
            )
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, value: emptyChartAppeared)
            Text("Not enough data yet")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Complete at least 2 workouts with this exercise to see your progress chart.")
                .font(.system(.caption))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .opacity(emptyChartAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: emptyChartAppeared)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        )
        .onAppear { emptyChartAppeared = true }
    }
}