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

    var body: some View {
        List {
            if let ns = namespace {
                Section {
                    exerciseDetailMatchedHeader(namespace: ns)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    exerciseNameRow
                } header: {
                    Text("Exercise Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // Note section - collapsed by default
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
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
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
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }

            // Rest Timer section - dedicated and visible
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(.body))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest Timer")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Persists across workouts")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            restTimerEnabled = nil
                            saveRestTimerPreference()
                        } label: {
                            Label("Use Global Default", systemImage: restTimerEnabled == nil ? "checkmark" : "")
                        }

                        Button {
                            restTimerEnabled = true
                            saveRestTimerPreference()
                        } label: {
                            Label("Always Show", systemImage: restTimerEnabled == true ? "checkmark" : "")
                        }

                        Button {
                            restTimerEnabled = false
                            saveRestTimerPreference()
                        } label: {
                            Label("Never Show", systemImage: restTimerEnabled == false ? "checkmark" : "")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(restTimerStatusText)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppColors.accent.opacity(0.15))
                        )
                    }
                }
                .padding(.vertical, 2)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            Section {
                if (exercise.sets ?? []).isEmpty {
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
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                } else {
                    let orderedSets = exercise.setsByOrder
                    let groups = computeSetGroups(orderedSets)

                    ForEach(groups) { group in
                        if group.isMultiSet {
                            // Grouped card: working set + trailing drop sets in one List row
                            VStack(spacing: 0) {
                                ForEach(Array(group.indices.enumerated()), id: \.element) { pos, setIdx in
                                    inlineGroupedSetRow(orderedSets[setIdx], index: setIdx, orderedSets: orderedSets)

                                    // Divider between rows (not after last)
                                    if pos < group.indices.count - 1 {
                                        Rectangle()
                                            .fill(SetType.dropSet.color.opacity(0.15))
                                            .frame(height: 1)
                                            .padding(.horizontal, 12)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(SetType.dropSet.color.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(alignment: .leading) {
                                // Continuous accent bar
                                Capsule()
                                    .fill(SetType.dropSet.color.opacity(0.5))
                                    .frame(width: 3)
                                    .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                            .listRowSeparator(.hidden)
                        } else {
                            // Standalone set: single row, unchanged visual
                            inlineSetRow(orderedSets[group.indices[0]], index: group.indices[0], orderedSets: orderedSets)
                        }
                    }
                    .onDelete { indexSet in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let currentOrderedSets = exercise.setsByOrder
                        let currentGroups = computeSetGroups(currentOrderedSets)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            for groupIdx in indexSet.sorted(by: >) where groupIdx < currentGroups.count {
                                for setIdx in currentGroups[groupIdx].indices.sorted(by: >) {
                                    exercise.removeSet(id: currentOrderedSets[setIdx].id)
                                }
                            }
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

                    // Rest timer (shows below sets when active)
                    if workout.isActive {
                        RestTimerView(exerciseId: exercise.id)
                            .listRowBackground(Color.white.opacity(0.06))
                            .listRowSeparator(.hidden)
                    }
                }

                if isAddingSet {
                    // Show QuickLogStrip for adding sets — pre-fill from last set if available, else 0/0
                    let exerciseIsTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                    let setsEmpty = (exercise.sets ?? []).isEmpty
                    HStack(spacing: 6) {
                        // Camera button alongside strip when adding the first set
                        if workout.isActive && !exerciseIsTimeBased && setsEmpty {
                            Button {
                                if ExerciseType.from(exerciseName: exercise.name) != nil {
                                    showCameraRepCounter = true
                                    Analytics.send(Analytics.Signal.cameraOpened, parameters: ["exerciseName": exercise.name])
                                } else {
                                    showingCameraUnsupported = true
                                }
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.accent.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        QuickLogStrip(
                            lastSet: exercise.setsByOrder.last,  // nil when no sets exist → 0/0 defaults
                            isTimeBased: exerciseIsTimeBased,
                            onLog: { reps, weight, duration in
                                if exerciseIsTimeBased {
                                    logSet(reps: 0, weight: 0, duration: duration)
                                } else {
                                    logSet(reps: reps, weight: weight)
                                }
                                // Close strip after logging
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isAddingSet = false
                                }
                            },
                            onCustom: nil  // No custom form needed - auto-chain handles everything
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                } else if (exercise.sets ?? []).isEmpty {
                    // No sets yet — Add Set + camera button
                    let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                    HStack(spacing: 10) {
                        if workout.isActive && !isTimeBased {
                            Button {
                                if ExerciseType.from(exerciseName: exercise.name) != nil {
                                    showCameraRepCounter = true
                                    Analytics.send(Analytics.Signal.cameraOpened, parameters: ["exerciseName": exercise.name])
                                } else {
                                    showingCameraUnsupported = true
                                }
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isAddingSet = true
                            }
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                                .font(.system(.body, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .tint(AppColors.accent)
                        .accessibilityIdentifier("addSetButton")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                } else {
                    // Sets exist — QuickLogStrip, hidden while rest timer is active
                    let shouldShowRest = workout.isActive
                        && restTimer.shouldShowFor(exerciseId: exercise.id)
                        && shouldOfferRestTimer(for: exercise.name)

                    if let lastSet = exercise.setsByOrder.last {
                        HStack(spacing: 6) {
                            // Camera rep counter button (only for supported exercises during active workout)
                            let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                            if workout.isActive && !isTimeBased {
                                Button {
                                    if ExerciseType.from(exerciseName: exercise.name) != nil {
                                        showCameraRepCounter = true
                                        Analytics.send(Analytics.Signal.cameraOpened, parameters: ["exerciseName": exercise.name])
                                    } else {
                                        showingCameraUnsupported = true
                                    }
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppColors.accent.opacity(0.8))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            QuickLogStrip(
                                lastSet: lastSet,
                                isTimeBased: ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false,
                                onLog: { reps, weight, duration in
                                    logSet(reps: reps, weight: weight, duration: duration)
                                },
                                onCustom: { openAddSetForm() }
                            )
                            // Force fresh init with the new lastSet whenever set count changes.
                            // Without this, SwiftUI may reuse the QuickLogStrip instance across the
                            // isAddingSet→sets-exist branch transition, preserving stale 0/0 state.
                            .id(exercise.sets?.count ?? 0)
                        }
                        .onChange(of: shouldShowRest) { oldValue, newValue in
                            if newValue {
                                // Rest timer showing - hide QuickLogStrip immediately (no animation)
                                quickLogStripOffset = 80
                                quickLogStripOpacity = 0
                            } else {
                                // Rest timer dismissed - animate QuickLogStrip in with bounce
                                withAnimation(.interpolatingSpring(stiffness: 150, damping: 12)) {
                                    quickLogStripOffset = 0
                                    quickLogStripOpacity = 1.0
                                }
                            }
                        }
                        .offset(y: quickLogStripOffset)
                        .opacity(quickLogStripOpacity)
                        .onAppear {
                            quickLogStripOffset = shouldShowRest ? 80 : 0
                            quickLogStripOpacity = shouldShowRest ? 0 : 1.0
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    }
                }
            } header: {
                Text("Sets")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Section {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                        HStack(spacing: 6) {
                            Image(systemName: isTimeBased ? "clock" : "number")
                                .font(.system(.caption, weight: .medium))
                            Text(isTimeBased ? "Total Time" : "Total Reps")
                                .font(.system(.caption, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        Text(isTimeBased ? UnitFormatter.formatDuration(exercise.totalDurationSeconds) : "\(exercise.totalReps)")
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                }
                .padding(.vertical, 8)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("Summary")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            // Personal Record section
            if let pr = currentPR {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "medal.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.yellow)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personal Record")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(pr.displayString)
                                .font(.system(.title3, weight: .bold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        if !pr.isBodyweight {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Est. 1RM")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                Text(UnitFormatter.formatWeightCompact(pr.estimated1RM))
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Label("Personal Best", systemImage: "medal")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // Progress section
            Section {
                Button {
                    showingProgress = true
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(AppColors.accent)

                        Text("View Progress")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(AppColors.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProgress) {
            ExerciseProgressView(exerciseName: exercise.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
        }
        .sheet(isPresented: $showingCameraUnsupported) {
            NavigationStack {
                List {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Not available for \(exercise.name)")
                                    .font(.system(.body, weight: .semibold))
                                Text("Camera rep counting works with these exercises:")
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section("Supported Exercises") {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage)
                                .font(.system(.subheadline))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
                .navigationTitle("Camera Tracking")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingCameraUnsupported = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(AppColors.background)
        }
        .fullScreenCover(isPresented: $showCameraRepCounter) {
            CameraRepCounterView(
                exerciseName: exercise.name,
                lastWeight: exercise.setsByOrder.last?.weight ?? 0,
                onSetLogged: { reps, weight in
                    logSet(reps: reps, weight: weight)
                }
            )
        }
        .overlay {
            // PR Celebration overlay (confetti + card)
            if showingPRCelebration {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    ConfettiView()
                    PRCelebrationView()
                        .transition(.scale.combined(with: .opacity))
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.28)) {
                            showingPRCelebration = false
                        }
                    }
                }
            }
        }
        .overlay {
            if keyboardVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        debugLog("[ExName] overlay tap: calling resignFirstResponder, exerciseNameFocused=\(exerciseNameFocused), isEditingExerciseName=\(isEditingExerciseName)")
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        debugLog("[ExName] overlay tap: after resignFirstResponder, exerciseNameFocused=\(exerciseNameFocused)")
                    }
                    .allowsHitTesting(true)
                    .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.28)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.28)) { keyboardVisible = false }
            if isEditingExerciseName {
                debugLog("[ExName] keyboardWillHide: saving and dismissing exercise name edit")
                saveExerciseName()
                isEditingExerciseName = false
                exerciseNameFocused = false
            }
        }
        .onAppear {
            exerciseNameText = exercise.name
            loadNote()
            loadPR()
            loadRestTimerPreference()
            // Auto-open QuickLogStrip for new empty exercises during active workouts
            if (exercise.sets ?? []).isEmpty && workout.isActive {
                isAddingSet = true
            }
        }
        .onChange(of: exercise.name) { oldValue, newValue in
            if !isEditingExerciseName {
                exerciseNameText = newValue
            }
        }
        .onChange(of: exerciseNameFocused) { oldValue, newValue in
            debugLog("[ExName] onChange(exerciseNameFocused): \(oldValue) → \(newValue), isEditingExerciseName=\(isEditingExerciseName)")
            if !newValue && isEditingExerciseName {
                debugLog("[ExName] onChange: saving and setting isEditingExerciseName=false")
                saveExerciseName()
                isEditingExerciseName = false
            }
        }
        .onChange(of: isNoteExpanded) { _, expanded in
            if expanded {
                noteFocused = true
            }
        }
    }

    private var exerciseNameRow: some View {
        HStack(spacing: 12) {
            if isEditingExerciseName {
                TextField("Exercise Name", text: $exerciseNameText)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .focused($exerciseNameFocused)
                    .textFieldStyle(.plain)
                    .onSubmit { submitExerciseName() }
            } else {
                Text(exercise.name)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditingExerciseName() }
            }
            Spacer()
            if !isEditingExerciseName {
                Button {
                    startEditingExerciseName()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(.caption, weight: .medium))
                }
                .tint(AppColors.accent)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Set Grouping (working set + trailing drop sets = one List row)

    private struct SetGroup: Identifiable {
        let id: UUID           // first set's ID (stable across re-renders)
        let indices: [Int]     // indices into orderedSets
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

    @ViewBuilder
    private func inlineSetRow(_ set: WorkoutSet, index: Int, orderedSets: [WorkoutSet]) -> some View {
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
            }
        )
        .id(set.id)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
        .listRowBackground(Color.white.opacity(0.06))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func inlineGroupedSetRow(_ set: WorkoutSet, index: Int, orderedSets: [WorkoutSet]) -> some View {
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
            onDelete: {
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
            },
            isInsideGroup: true
        )
        .id(set.id)
        .transition(.asymmetric(
            insertion: .push(from: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    @ViewBuilder
    private func exerciseDetailMatchedHeader(namespace: Namespace.ID) -> some View {
        HStack(spacing: 12) {
            if isEditingExerciseName {
                TextField("Exercise Name", text: $exerciseNameText)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .focused($exerciseNameFocused)
                    .textFieldStyle(.plain)
                    .onSubmit { submitExerciseName() }
            } else {
                Text(exercise.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditingExerciseName() }
                    .matchedGeometryEffect(id: "title-\(exercise.id)", in: namespace)
            }
            Spacer(minLength: 0)
            if !isEditingExerciseName {
                Button {
                    startEditingExerciseName()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(.caption, weight: .medium))
                }
                .tint(.accentColor)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .matchedGeometryEffect(id: "card-\(exercise.id)", in: namespace)
        )
    }

    private func startEditingExerciseName() {
        debugLog("[ExName] startEditingExerciseName")
        exerciseNameText = exercise.name
        isEditingExerciseName = true
        exerciseNameFocused = true
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
        debugLog("[ExName] submitExerciseName called (from .onSubmit / Done button)")
        saveExerciseName()
        // Defer focus change to next run loop — setting @FocusState during
        // .onSubmit gets batched with other state changes, so the keyboard
        // never actually dismisses. The onChange(of: exerciseNameFocused)
        // handler then removes the TextField after focus is confirmed lost.
        debugLog("[ExName] scheduling Task to set exerciseNameFocused=false")
        Task { @MainActor in
            debugLog("[ExName] Task executing: setting exerciseNameFocused=false (currently \(exerciseNameFocused))")
            exerciseNameFocused = false
            debugLog("[ExName] Task done: exerciseNameFocused is now \(exerciseNameFocused)")
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            debugLog("Error saving exercise: \(error)")
        }
    }

    /// Log a set with all side effects (widget sync, live activity, PR check, rest offer)
    private func logSet(reps: Int, weight: Double, duration: Int? = nil) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if timeBased, let d = duration {
                exercise.addSet(reps: 0, weight: 0, durationSeconds: d)
            } else {
                exercise.addSet(reps: reps, weight: weight)
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
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            workoutId: workout.id,
            modelContext: modelContext
        )
        debugLog("[PR] checkAndSavePR returned isNewPR=\(isNewPR)")

        if isNewPR {
            // Reload PR and show celebration
            loadPR()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showingPRCelebration = true
            }

            // Haptic feedback for PR
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
