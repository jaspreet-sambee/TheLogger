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
                    
                    Text("Last updated: March 2026")
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
                    
                    Text("TheLogger is designed with your privacy as a priority. Your workout data is stored on your device and can be optionally backed up to your personal iCloud account — never to our servers.")
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
                    
                    This data is stored using Apple's SwiftData framework on your device. It may be backed up to your personal iCloud account if iCloud is enabled — it is never sent to our servers.
                    """
                )
                
                policySection(
                    title: "Data Storage",
                    icon: "iphone",
                    content: """
                    All data is stored locally on your device using Apple's secure storage. We do not operate any servers or collect your data.

                    Optional iCloud Backup: If you have iCloud enabled on your device, your workout data may be automatically backed up via Apple's CloudKit service — this uses your personal Apple iCloud account, not our infrastructure. You can disable iCloud backup at any time in iOS Settings → [Your Name] → iCloud → TheLogger.

                    We do not use:
                    • Our own servers or databases
                    • Third-party analytics
                    • Advertising networks
                    • User tracking or profiling

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
                    title: "Camera",
                    icon: "camera",
                    content: """
                    TheLogger uses your device's camera to count reps using on-device pose detection. Camera data is processed entirely on your device in real time — no video or images are stored, transmitted, or shared. The camera is only active when you explicitly start a camera rep counting session.
                    """
                )

                policySection(
                    title: "Third-Party Services",
                    icon: "network",
                    content: """
                    TheLogger does not integrate with any third-party analytics, advertising, or tracking services. The app's core functionality works entirely offline. An internet connection is only used when syncing with your personal iCloud account.
                    """
                )
                
                policySection(
                    title: "Data Deletion",
                    icon: "trash",
                    content: """
                    You can delete your data at any time by:

                    • Deleting individual workouts within the app
                    • Uninstalling the app (removes all local app data)

                    If iCloud backup is enabled, you can also remove TheLogger's iCloud data via iOS Settings → [Your Name] → iCloud → Manage Account Storage → TheLogger.
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
                    If you have questions about this privacy policy, please visit thelogger.app or contact us through the App Store.
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



