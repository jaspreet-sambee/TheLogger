//
//  MainTabView.swift
//  TheLogger
//
//  Root tab view after onboarding — Home / Stats / Profile
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Binding var deepLinkWorkoutId: UUID?
    @Binding var deepLinkExerciseId: UUID?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutListView(
                deepLinkWorkoutId: $deepLinkWorkoutId,
                deepLinkExerciseId: $deepLinkExerciseId
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            StatsDashboardView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(AppColors.accent)
        .onChange(of: deepLinkWorkoutId) { _, newValue in
            if newValue != nil {
                selectedTab = 0
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            let tabName = switch newValue {
            case 0: "home"
            case 1: "stats"
            case 2: "profile"
            default: "unknown"
            }
            Analytics.send(Analytics.Signal.tabSelected, parameters: ["tab": tabName])
        }
    }
}

#Preview {
    MainTabView(
        deepLinkWorkoutId: .constant(nil),
        deepLinkExerciseId: .constant(nil)
    )
    .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self], inMemory: true)
}
