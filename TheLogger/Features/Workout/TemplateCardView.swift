//
//  TemplateCardView.swift
//
//  Card view for displaying a template in the workout selector
//

import SwiftUI

struct TemplateCardView: View {
    let template: Workout

    var body: some View {
        HStack(spacing: 16) {
            // Icon/Visual Indicator
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(template.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    // Exercise count
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(template.exerciseCount)")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(template.exerciseCount == 1 ? "exercise" : "exercises")
                            .font(.system(.caption, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    // Set count (if template has sets)
                    if template.totalSets > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(template.totalSets)")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(template.totalSets == 1 ? "set" : "sets")
                                .font(.system(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.accent.opacity(0.35), lineWidth: 1)
        )
    }
}
