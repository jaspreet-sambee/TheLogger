//
//  WorkoutHistoryView.swift
//
//  Sheet view for browsing full workout history
//

import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    let workouts: [Workout]
    var onLogAgain: ((Workout) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var showingDeleteWorkoutConfirmation = false
    @State private var pendingDeleteWorkout: Workout?

    // Group workouts by date
    private var groupedWorkouts: [(Date, [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.startOfDay(for: workout.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDay = calendar.startOfDay(for: date)

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: workoutDay, to: today).day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Completed workouts will appear here")
                    )
                } else {
                    ForEach(groupedWorkouts, id: \.0) { date, workoutsForDate in
                        Section {
                            ForEach(workoutsForDate) { workout in
                                ZStack {
                                    NavigationLink(value: workout.id.uuidString) {
                                        Color.clear
                                            .contentShape(Rectangle())
                                    }

                                    HistoryWorkoutRowView(workout: workout)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    pendingDeleteWorkout = workoutsForDate[index]
                                    showingDeleteWorkoutConfirmation = true
                                }
                            }
                        } header: {
                            HStack {
                                Text(sectionHeader(for: date))
                                    .font(.system(.subheadline, weight: .semibold))
                                Spacer()
                                Text("\(workoutsForDate.count)")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        }
                    }
                }
            }
            .navigationDestination(for: String.self) { workoutId in
                if let workout = workouts.first(where: { $0.id.uuidString == workoutId }) {
                    WorkoutDetailView(workout: workout, onLogAgain: onLogAgain)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(AppColors.background)
        .alert("Delete Workout", isPresented: $showingDeleteWorkoutConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingDeleteWorkout = nil
            }
            Button("Delete", role: .destructive) {
                if let workout = pendingDeleteWorkout {
                    modelContext.delete(workout)
                    try? modelContext.save()
                    pendingDeleteWorkout = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(pendingDeleteWorkout?.name ?? "")\"? This cannot be undone.")
        }
    }
}
