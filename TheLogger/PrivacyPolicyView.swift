//
//  PrivacyPolicyView.swift
//  TheLogger
//
//  Privacy policy display for App Store compliance
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.system(.largeTitle, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Last updated: January 2026")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                
                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AppColors.accentGold)
                        Text("Privacy First")
                            .font(.system(.headline, weight: .semibold))
                    }
                    
                    Text("TheLogger is designed with your privacy as a priority. All your workout data stays on your device and is never sent to external servers.")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accentGold.opacity(0.08))
                )
                
                // Sections
                policySection(
                    title: "Data Collection",
                    icon: "doc.text",
                    content: """
                    TheLogger collects and stores the following data locally on your device:
                    
                    • Workout history (exercises, sets, weights, reps)
                    • Personal records
                    • Workout templates
                    • User preferences (name, units, settings)
                    • Exercise notes
                    
                    This data is stored using Apple's SwiftData framework and never leaves your device unless you explicitly export it.
                    """
                )
                
                policySection(
                    title: "Data Storage",
                    icon: "iphone",
                    content: """
                    All data is stored locally on your device using Apple's secure storage mechanisms. We do not use:
                    
                    • Cloud servers
                    • Third-party analytics
                    • Advertising networks
                    • User tracking
                    
                    Your data remains under your complete control at all times.
                    """
                )
                
                policySection(
                    title: "Data Export",
                    icon: "square.and.arrow.up",
                    content: """
                    You can export your workout history as a CSV file at any time through the app's export feature. This exported file is created locally and you choose where to save or share it.
                    """
                )
                
                policySection(
                    title: "Third-Party Services",
                    icon: "network",
                    content: """
                    TheLogger does not integrate with any third-party services. The app functions entirely offline and does not require an internet connection.
                    """
                )
                
                policySection(
                    title: "Data Deletion",
                    icon: "trash",
                    content: """
                    You can delete your data at any time by:
                    
                    • Deleting individual workouts within the app
                    • Uninstalling the app (removes all app data)
                    
                    There is no cloud backup, so deletion is permanent.
                    """
                )
                
                policySection(
                    title: "Children's Privacy",
                    icon: "person.2",
                    content: """
                    TheLogger does not knowingly collect any personal information from children. The app is designed for general audiences and contains no age-restricted content.
                    """
                )
                
                policySection(
                    title: "Changes to This Policy",
                    icon: "doc.badge.clock",
                    content: """
                    We may update this privacy policy from time to time. Any changes will be reflected in the app with an updated "Last updated" date.
                    """
                )
                
                policySection(
                    title: "Contact",
                    icon: "envelope",
                    content: """
                    If you have questions about this privacy policy, please contact us through the App Store.
                    """
                )
                
                // Footer
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical, 16)
                    
                    Text("TheLogger respects your privacy.")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("No accounts. No tracking. Just lifting.")
                        .font(.system(.caption2, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func policySection(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text(title)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(content)
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}



