//
//  TemplateRowView.swift
//
//  Row view for displaying a workout template
//

import SwiftUI

struct TemplateRowView: View {
    let template: Workout

    // Get first few exercise names for preview (in saved order)
    private var exercisePreview: [String] {
        Array(template.exercisesByOrder.prefix(3).map { $0.name })
    }

    private var remainingCount: Int {
        max(0, template.exercisesByOrder.count - 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            Text(template.name)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Exercise chips
            if !exercisePreview.isEmpty {
                HStack(spacing: 6) {
                    ForEach(exercisePreview, id: \.self) { exercise in
                        Text(exercise)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                            .lineLimit(1)
                    }

                    if remainingCount > 0 {
                        Text("+\(remainingCount)")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
            } else {
                Text("No exercises yet")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(.vertical, 14)
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
