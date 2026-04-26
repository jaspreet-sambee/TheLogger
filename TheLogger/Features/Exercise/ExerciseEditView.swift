//
//  ExerciseEditView.swift
//  TheLogger
//
//  Exercise edit view with sets, notes, rest timer, and PR tracking
//

import SwiftUI
import SwiftData

// MARK: - Exercise Edit View
struct ExerciseEditView: View {
    @Bindable var exercise: Exercise
    let workout: Workout
    var namespace: Namespace.ID? = nil
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = false
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @State private var isAddingSet = false
    @State private var newSetReps: Int = 0
    @State private var newSetWeight: Double = 0
    @State private var newSetDuration: Int = 30
    @State private var isEditingExerciseName = false
    @State private var exerciseNameText = ""
    @State private var showingProgress = false
    @State private var showingPRCelebration = false
    @State private var prCelebrationData: PRCelebrationData?
    @State private var currentPR: PersonalRecord?
    @FocusState private var focusedField: SetInputField?
    @FocusState private var exerciseNameFocused: Bool
    @State private var isNoteExpanded = false
    @State private var noteText = ""
    @FocusState private var noteFocused: Bool
    @State private var keyboardVisible = false
    private let restTimer = RestTimerManager.shared
    @State private var restTimerEnabled: Bool? = nil  // nil = global default, true/false = explicit
    @State private var quickLogStripOffset: CGFloat = 50
    @State private var quickLogStripOpacity: Double = 0
    @State private var showCameraRepCounter = false  // Camera-based rep counting
    @State private var showingCameraUnsupported = false
    @State private var lastCameraSetWasPR = false  // Set by checkForPR; read by camera onSetLogged closure
    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                // Note section
                noteSection

                // Cohesive sets + log section (single list row)
                Section {
                    setsAndLogSection
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                } header: {
                    Text("SETS")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .kerning(0.5)
                        .textCase(nil)
                }

                // Camera + info chips + progress (rest of body)
                exerciseInfoSections
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.background)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.28)) { keyboardVisible = true }
                // Scroll to the editing set when keyboard appears
                if let editingSetId = findEditingSetId() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollProxy.scrollTo("setRow-\(editingSetId)", anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button { startEditingExerciseName() } label: {
                    VStack(spacing: 1) {
                        Text(exercise.name).font(.system(size: 18, weight: .heavy)).foregroundStyle(.primary)
                        if let muscle = ExerciseLibrary.shared.find(name: exercise.name)?.muscleGroup.rawValue {
                            let setCount = exercise.sets?.count ?? 0
                            Text("\(muscle) · \(setCount) \(setCount == 1 ? "set" : "sets")")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.30))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Rename Exercise", isPresented: $isEditingExerciseName) {
            TextField("Exercise name", text: $exerciseNameText)
            Button("Save") { submitExerciseName() }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingProgress) {
            ExerciseProgressView(exerciseName: exercise.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
        }
        .sheet(isPresented: $showingCameraUnsupported) {
            cameraUnsupportedSheet
        }
        .fullScreenCover(isPresented: $showCameraRepCounter) {
            CameraRepCounterView(
                exerciseName: exercise.name,
                lastWeight: exercise.setsByOrder.last?.weight ?? 0,
                onSetLogged: { reps, weight, tempoDown, tempoUp in
                    logSet(reps: reps, weight: weight)
                    // Save tempo data to the just-logged set
                    if let lastSet = exercise.setsByOrder.last {
                        lastSet.tempoDown = tempoDown
                        lastSet.tempoUp = tempoUp
                    }
                }
            )
        }
        .overlay { prCelebrationOverlay }
        .overlay { keyboardDismissOverlay }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.28)) { keyboardVisible = false }
        }
        .onAppear {
            exercise.repairSortOrderIfNeeded()
            exerciseNameText = exercise.name
            loadNote(); loadPR(); loadRestTimerPreference()
            if (exercise.sets ?? []).isEmpty && workout.isActive { isAddingSet = true }
        }
        .onChange(of: exercise.name) { _, newValue in
            if !isEditingExerciseName { exerciseNameText = newValue }
        }
        .onChange(of: isNoteExpanded) { _, expanded in
            if expanded { noteFocused = true }
        }
    }

    // MARK: - Overlay Helpers

    @ViewBuilder
    private var prCelebrationOverlay: some View {
        if showingPRCelebration, let data = prCelebrationData {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.28)) { showingPRCelebration = false }
                    }
                ConfettiView()
                PRCelebrationCard(data: data) {
                    withAnimation(.easeOut(duration: 0.28)) { showingPRCelebration = false }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var keyboardDismissOverlay: some View {
        if keyboardVisible {
            Color.clear.contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .allowsHitTesting(true).transition(.opacity)
        }
    }

    private var cameraUnsupportedSheet: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.accent.opacity(0.6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not available for \(exercise.name)")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Camera rep counting works with these exercises:")
                                .font(.system(.subheadline))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                Section {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.primary)
                            .listRowBackground(Color.white.opacity(0.06))
                    }
                } header: {
                    Text("Supported Exercises")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(.uppercase)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Camera Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingCameraUnsupported = false }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(AppColors.background)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Section {
                if isNoteExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add a note (e.g., grip width, tempo)", text: $noteText, axis: .vertical)
                            .font(.system(.subheadline))
                            .foregroundStyle(.primary)
                            .focused($noteFocused)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .onChange(of: noteFocused) { oldValue, newValue in
                                if !newValue {
                                    saveNote()
                                }
                            }
                            .onSubmit {
                                saveNote()
                            }

                        HStack {
                            Text("Persists across workouts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Done") {
                                saveNote()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isNoteExpanded = false
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isNoteExpanded = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: noteText.isEmpty ? "note.text.badge.plus" : "note.text")
                                .font(.system(.subheadline))
                                .foregroundStyle(noteText.isEmpty ? Color.secondary : AppColors.accent)

                            if noteText.isEmpty {
                                Text("Add note")
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(noteText)
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
        }
    }

    // MARK: - Cohesive Sets + Log Section

    @ViewBuilder
    private var setsAndLogSection: some View {
        let hasSets = !(exercise.sets ?? []).isEmpty
        let shouldShowRest = workout.isActive
            && restTimer.shouldShowFor(exerciseId: exercise.id)
            && shouldOfferRestTimer(for: exercise.name)

        VStack(spacing: 12) {
            if hasSets {
                unifiedSetsContainer
                if shouldShowRest {
                    RestTimerView(exerciseId: exercise.id)
                }
            } else {
                setsEmptyState
            }
            quickLogArea
        }
    }

    // MARK: - Camera + Info Chips + Progress

    @ViewBuilder
    private var exerciseInfoSections: some View {
        // Camera rep counter (active workout, non-time-based only)
        let exerciseIsTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
        if workout.isActive && !exerciseIsTimeBased {
            Section {
                cameraCard
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.accent.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.accent.opacity(0.18), lineWidth: 1))
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }

        // Info chips: Rest Timer + PR
        Section {
            infoChipsRow
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }

        // Progress
        Section {
            progressRow
                .listRowBackground(Color.white.opacity(0.06))
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
    }

    private var cameraCard: some View {
        Button {
            if ExerciseType.from(exerciseName: exercise.name) != nil {
                showCameraRepCounter = true
                Analytics.send(Analytics.Signal.cameraOpened, parameters: ["exerciseName": exercise.name])
            } else {
                showingCameraUnsupported = true
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppColors.accent.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "camera.viewfinder").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Camera Rep Counter").font(.system(.subheadline, weight: .bold)).foregroundStyle(.primary)
                    Text("Auto-count reps using your camera").font(.system(.caption, weight: .regular)).foregroundStyle(Color.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(.caption, weight: .semibold)).foregroundStyle(AppColors.accent.opacity(0.6))
            }
            .padding(.vertical, 10).padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private var infoChipsRow: some View {
        HStack(spacing: 10) {
            restTimerChip
            prChip
        }
    }

    private var restTimerChip: some View {
        Menu {
            Button { restTimerEnabled = nil; saveRestTimerPreference() } label: { Label("Use Global Default", systemImage: restTimerEnabled == nil ? "checkmark" : "") }
            Button { restTimerEnabled = true; saveRestTimerPreference() } label: { Label("Always Show", systemImage: restTimerEnabled == true ? "checkmark" : "") }
            Button { restTimerEnabled = false; saveRestTimerPreference() } label: { Label("Never Show", systemImage: restTimerEnabled == false ? "checkmark" : "") }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "timer").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColors.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("REST TIMER").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.white.opacity(0.30)).kerning(0.4)
                    Text(restTimerStatusText).font(.system(.caption, weight: .semibold)).foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.25))
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.09), lineWidth: 1)))
        }
    }

    @ViewBuilder
    private var prChip: some View {
        if let pr = currentPR {
            HStack(spacing: 6) {
                Text("🏆").font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text("CURRENT PR").font(.system(size: 9, weight: .semibold)).foregroundStyle(AppColors.accentGold.opacity(0.5)).kerning(0.4)
                    Text(pr.isBodyweight ? "BW × \(pr.reps)" : "\(UnitFormatter.formatWeightCompact(pr.weight, showUnit: false)) × \(pr.reps)")
                        .font(.system(.caption, weight: .bold)).foregroundStyle(AppColors.accentGold)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accentGold.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accentGold.opacity(0.18), lineWidth: 1)))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "medal").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("PERSONAL RECORD").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.white.opacity(0.20)).kerning(0.4)
                    Text("Not set yet").font(.system(.caption, weight: .medium)).foregroundStyle(Color.white.opacity(0.30))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1)))
        }
    }

    private var progressRow: some View {
        Button { showingProgress = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(.subheadline))
                    .foregroundStyle(AppColors.accent)
                Text("View Progress")
                    .font(.system(.subheadline))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var setsEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No sets added yet")
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var quickLogArea: some View {
        let hasSets = !(exercise.sets ?? []).isEmpty
        let exerciseIsTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
        let shouldShowRest = workout.isActive
            && restTimer.shouldShowFor(exerciseId: exercise.id)
            && shouldOfferRestTimer(for: exercise.name)

        if isAddingSet {
            QuickLogStrip(
                lastSet: exercise.setsByOrder.last,
                isTimeBased: exerciseIsTimeBased,
                setCount: exercise.sets?.count ?? 0,
                onLog: { reps, weight, duration, setType in
                    if exerciseIsTimeBased {
                        logSet(reps: 0, weight: 0, duration: duration, setType: setType)
                    } else {
                        logSet(reps: reps, weight: weight, setType: setType)
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isAddingSet = false
                    }
                },
                onCustom: nil
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity.combined(with: .move(edge: .bottom))
            ))
        } else if !hasSets {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isAddingSet = true
                }
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accent.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accent.opacity(0.22), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addSetButton")
        } else if !shouldShowRest, let lastSet = exercise.setsByOrder.last {
                QuickLogStrip(
                    lastSet: lastSet,
                    isTimeBased: exerciseIsTimeBased,
                    setCount: exercise.sets?.count ?? 0,
                    onLog: { reps, weight, duration, setType in
                        logSet(reps: reps, weight: weight, duration: duration, setType: setType)
                    },
                    onCustom: { openAddSetForm() }
                )
                .id(exercise.sets?.count ?? 0)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
        }
    }

    // MARK: - Set Grouping (working set + trailing drop sets)

    private struct SetGroup: Identifiable {
        let id: UUID
        let indices: [Int]
        var isMultiSet: Bool { indices.count > 1 }
    }

    private func computeSetGroups(_ orderedSets: [WorkoutSet]) -> [SetGroup] {
        var groups: [SetGroup] = []
        var current: [Int] = []
        for (i, set) in orderedSets.enumerated() {
            if set.type == .dropSet && !current.isEmpty {
                current.append(i)
            } else {
                if !current.isEmpty {
                    groups.append(SetGroup(id: orderedSets[current[0]].id, indices: current))
                }
                current = [i]
            }
        }
        if !current.isEmpty {
            groups.append(SetGroup(id: orderedSets[current[0]].id, indices: current))
        }
        return groups
    }

    // MARK: - Unified Sets Container (inline editing, mockup container style)

    private var unifiedSetsContainer: some View {
        let orderedSets = exercise.setsByOrder
        let groups = computeSetGroups(orderedSets)

        return VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { groupIdx, group in
                if group.isMultiSet {
                    // Drop set group: accent bar + grouped rows
                    VStack(spacing: 0) {
                        ForEach(Array(group.indices.enumerated()), id: \.element) { pos, setIdx in
                            makeSetRow(orderedSets[setIdx], index: setIdx)
                            if pos < group.indices.count - 1 {
                                Rectangle()
                                    .fill(SetType.dropSet.color.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SetType.dropSet.color.opacity(0.5))
                            .frame(width: 3)
                            .padding(.vertical, 4)
                    }
                } else {
                    makeSetRow(orderedSets[group.indices[0]], index: group.indices[0])
                }

                if groupIdx < groups.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func makeSetRow(_ set: WorkoutSet, index: Int) -> some View {
        InlineSetRowView(
            set: set,
            setNumber: index + 1,
            exerciseName: exercise.name,
            currentWorkout: workout,
            modelContext: modelContext,
            onUpdate: { newReps, newWeight in
                if !(ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false) {
                    set.reps = newReps
                    set.weight = newWeight
                }
                saveChanges()
                loadPR()
            },
            onPRSet: {
                DispatchQueue.main.async { loadPR() }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showingPRCelebration = true
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            },
            onDelete: { deleteSet(set) },
            isInsideGroup: true
        )
        .id(set.id)
    }

    /// Find the ID string of the set currently being keyboard-edited (for scroll-to)
    private func findEditingSetId() -> String? {
        // We can't directly query InlineSetRowView's state from here,
        // but we know the last set or any set the user tapped will be editing.
        // Use the last set in the list as a reasonable scroll target.
        return exercise.setsByOrder.last?.id.uuidString
    }

    private func deleteSet(_ set: WorkoutSet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            exercise.removeSet(id: set.id)
        }
        saveChanges()
        PersonalRecordManager.recalculatePR(exerciseName: exercise.name, modelContext: modelContext)
        loadPR()
        if workout.isActive {
            workout.syncToWidget(currentExercise: exercise)
            let lastSet = exercise.setsByOrder.last
            let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
            Task {
                await LiveActivityManager.shared.updateActivity(
                    exerciseName: exercise.name,
                    exerciseId: exercise.id,
                    exerciseSets: (exercise.sets ?? []).count,
                    lastReps: timeBased ? 0 : (lastSet?.reps ?? 0),
                    lastWeight: timeBased ? 0 : (lastSet?.weight ?? 0)
                )
            }
        }
    }

    private func findBestSetIndex(_ sets: [WorkoutSet]) -> Int? {
        var bestScore = 0.0
        var bestIdx: Int? = nil
        for (i, s) in sets.enumerated() {
            guard s.type.countsForPR, s.reps > 0 else { continue }
            let score = s.weight > 0 ? s.weight * (1.0 + Double(s.reps) / 30.0) : Double(s.reps)
            if score > bestScore { bestScore = score; bestIdx = i }
        }
        return bestIdx
    }



    private func startEditingExerciseName() {
        exerciseNameText = exercise.name
        isEditingExerciseName = true
    }

    private func saveExerciseName() {
        debugLog("[ExName] saveExerciseName called, isEditingExerciseName=\(isEditingExerciseName), exerciseNameFocused=\(exerciseNameFocused)")
        let trimmed = exerciseNameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            exercise.name = trimmed
            saveChanges()
        } else {
            // Revert to original if empty
            exerciseNameText = exercise.name
        }
    }

    private func submitExerciseName() {
        saveExerciseName()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            debugLog("Error saving exercise: \(error)")
        }
    }

    /// Log a set with all side effects (widget sync, live activity, PR check, rest offer)
    private func logSet(reps: Int, weight: Double, duration: Int? = nil, setType: SetType = .working) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if timeBased, let d = duration {
                exercise.addSet(reps: 0, weight: 0, durationSeconds: d)
            } else {
                exercise.addSet(reps: reps, weight: weight)
            }
            // Apply the selected set type to the just-added set
            if let lastSet = exercise.setsByOrder.last {
                lastSet.type = setType
            }
        }
        saveChanges()
        workout.syncToWidget(currentExercise: exercise)

        Task {
            await LiveActivityManager.shared.updateActivity(
                exerciseName: exercise.name,
                exerciseId: exercise.id,
                exerciseSets: (exercise.sets ?? []).count,
                lastReps: timeBased ? 0 : reps,
                lastWeight: timeBased ? 0 : weight
            )
        }

        if !timeBased {
            checkForPR(weight: weight, reps: reps)
        }

        if workout.isActive && workout.isLastInSuperset(exercise) {
            // Check per-exercise preference before offering rest
            if shouldOfferRestTimer(for: exercise.name) {
                let restDuration = Self.suggestedRestDuration(for: exercise.name)
                RestTimerManager.shared.offerRest(for: exercise.id, duration: restDuration, autoStart: autoStartRestTimer)
            }
        }
    }

    /// Open the inline add-set form, pre-filled from the last logged set
    private func openAddSetForm() {
        RestTimerManager.shared.pause()
        let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
        if workout.isActive, let lastSet = exercise.setsByOrder.last {
            if timeBased {
                newSetDuration = lastSet.durationSeconds ?? 30
            } else {
                newSetReps = lastSet.reps
                newSetWeight = lastSet.weight
            }
        } else {
            newSetReps = 0
            newSetWeight = 0
            newSetDuration = 30
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isAddingSet = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = timeBased ? .duration : .reps
        }
    }

    /// Suggest rest duration based on exercise type (uses library)
    private static func suggestedRestDuration(for exerciseName: String) -> Int {
        ExerciseLibrary.shared.restDuration(for: exerciseName)
    }

    private var restTimerEnabledIcon: String {
        switch restTimerEnabled {
        case nil: return "circle.dotted"           // Using global default
        case true: return "checkmark.circle.fill"  // Always show
        case false: return "xmark.circle.fill"     // Never show
        }
    }

    private var restTimerEnabledColor: Color {
        switch restTimerEnabled {
        case nil: return .secondary
        case true: return .green
        case false: return .red.opacity(0.7)
        }
    }

    private var restTimerStatusText: String {
        switch restTimerEnabled {
        case nil: return "Default"
        case true: return "Always"
        case false: return "Never"
        }
    }

    private func loadNote() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                noteText = memory.note ?? ""
            }
        } catch {
            debugLog("Error loading note: \(error)")
        }
    }

    private func saveNote() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                memory.updateNote(noteText)
                try modelContext.save()
            } else if !noteText.isEmpty {
                // Create new memory with note
                let newMemory = ExerciseMemory(name: exercise.name, note: noteText)
                modelContext.insert(newMemory)
                try modelContext.save()
            }
            Analytics.send(Analytics.Signal.exerciseNoteEdited, parameters: ["exerciseName": exercise.name])
        } catch {
            debugLog("Error saving note: \(error)")
        }
    }

    /// Determine if rest timer should be offered based on per-exercise preference
    private func shouldOfferRestTimer(for exerciseName: String) -> Bool {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<ExerciseMemory>()
        let globalEnabled = UserDefaults.standard.bool(forKey: "globalRestTimerEnabled")

        guard let memories = try? modelContext.fetch(descriptor),
              let memory = memories.first(where: { $0.normalizedName == normalizedName }) else {
            return globalEnabled
        }

        // Per-exercise preference takes priority over global default
        if let enabled = memory.restTimerEnabled {
            return enabled
        }

        return globalEnabled
    }

    private func loadRestTimerPreference() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                restTimerEnabled = memory.restTimerEnabled
            }
        } catch {
            debugLog("Error loading rest timer preference: \(error)")
        }
    }

    private func saveRestTimerPreference() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                memory.updateRestTimerEnabled(restTimerEnabled)
                try modelContext.save()
            } else {
                // Create new memory with rest timer preference
                let newMemory = ExerciseMemory(
                    name: exercise.name,
                    restTimerEnabled: restTimerEnabled
                )
                modelContext.insert(newMemory)
                try modelContext.save()
            }

            // Provide haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            debugLog("Error saving rest timer preference: \(error)")
        }
    }

    private func loadPR() {
        currentPR = PersonalRecordManager.getPR(for: exercise.name, modelContext: modelContext)
        if currentPR == nil {
            // No PR record yet — scan all historical workouts to bootstrap one.
            // This handles exercises logged before PR tracking was introduced.
            PersonalRecordManager.recalculatePR(exerciseName: exercise.name, modelContext: modelContext)
            currentPR = PersonalRecordManager.getPR(for: exercise.name, modelContext: modelContext)
        }
    }

    private func checkForPR(weight: Double, reps: Int) {
        debugLog("[PR] checkForPR called - exercise=\(exercise.name), weight=\(weight), reps=\(reps)")

        // Capture previous PR before it gets overwritten
        let previousPR = PersonalRecordManager.getPR(for: exercise.name, modelContext: modelContext)
        let prevWeight = previousPR?.weight
        let prevReps = previousPR?.reps
        let prev1RM = previousPR?.estimated1RM

        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            workoutId: workout.id,
            modelContext: modelContext
        )
        debugLog("[PR] checkAndSavePR returned isNewPR=\(isNewPR)")
        lastCameraSetWasPR = isNewPR

        if isNewPR {
            loadPR()

            // Build celebration data
            let est1RM = weight > 0 ? weight * (1.0 + Double(reps) / 30.0) : 0
            prCelebrationData = PRCelebrationData(
                exerciseName: exercise.name,
                weight: weight,
                reps: reps,
                estimated1RM: est1RM,
                previousWeight: prevWeight,
                previousReps: prevReps,
                previous1RM: prev1RM,
                isBodyweight: weight == 0
            )

            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showingPRCelebration = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
