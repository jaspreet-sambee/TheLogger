//
//  WorkoutSelectorView.swift
//
//  Sheet for selecting a template or starting a new workout
//

import SwiftUI
import SwiftData

struct WorkoutSelectorView: View {
    let templates: [Workout]
    let onSelect: (Workout?) -> Void  // nil = start new, Workout = use template
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Full screen background
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Start New Workout option - Prominent card
                        Button {
                            onSelect(nil)
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent.opacity(0.15))
                                        .frame(width: 48, height: 48)

                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(AppColors.accent)
                                }

                                VStack(spacing: 4) {
                                    Text("Start New Workout")
                                        .font(.system(.title2, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Create a workout from scratch")
                                        .font(.system(.subheadline, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Templates Section
                        if !templates.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(AppColors.accent)
                                    Text("Templates")
                                        .font(.system(.title3, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(templates.count)")
                                        .font(.system(.subheadline, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.08))
                                        )
                                }
                                .padding(.horizontal, 16)

                                ForEach(templates) { template in
                                    Button {
                                        onSelect(template)
                                    } label: {
                                        TemplateCardView(template: template)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 8)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                Text("No Templates")
                                    .font(.system(.headline, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Create templates to quickly start workouts")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(AppColors.background)
    }
}
