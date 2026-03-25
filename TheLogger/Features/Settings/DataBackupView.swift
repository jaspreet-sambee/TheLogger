//
//  DataBackupView.swift
//  TheLogger
//
//  Export/import UI for full JSON backups and CSV exports.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static var theloggerBackup: UTType {
        UTType(exportedAs: "com.thelogger.backup", conformingTo: .json)
    }
}

struct DataBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ProManager.self) private var proManager
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    @State private var showUpgrade = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var showingFileImporter = false
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var isExporting = false

    private var completedWorkouts: [Workout] {
        allWorkouts.filter { !$0.isTemplate && $0.endTime != nil }
    }

    private var templates: [Workout] {
        allWorkouts.filter { $0.isTemplate }
    }

    private var dateRangeText: String? {
        guard let first = completedWorkouts.last?.date,
              let last = completedWorkouts.first?.date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    var body: some View {
        NavigationStack {
            List {
                statsSection
                exportSection
                importSection
                infoSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Data & Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ExportShareSheet(url: url)
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeView()
                    .environment(proManager)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.theloggerBackup, .json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                if let r = importResult {
                    Text("Imported \(r.workoutsImported) workout\(r.workoutsImported == 1 ? "" : "s"). \(r.skipped) skipped (duplicates). \(r.memoriesUpdated) exercise settings updated. \(r.prsUpdated) personal records updated.")
                }
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK") { }
            } message: {
                Text(importError ?? "Unknown error")
            }
        }
        .presentationBackground(AppColors.background)
    }

    // MARK: - Sections

    private var statsSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    StatBadge(label: "Workouts", value: "\(completedWorkouts.count)")
                    StatBadge(label: "Templates", value: "\(templates.count)")
                }
                if let range = dateRangeText {
                    Text(range)
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        } header: {
            Text("Your Data")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var exportSection: some View {
        Section {
            if proManager.isPro {
                Button {
                    exportFullBackup()
                } label: {
                    ExportRowLabel(
                        iconName: "arrow.down.doc.fill",
                        iconColor: AppColors.accent,
                        title: "Export Full Backup",
                        subtitle: "All workouts, templates, PRs, and settings",
                        badge: isExporting ? nil : ".thelogger",
                        showProgress: isExporting
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exportFullBackupButton")
            } else {
                Button { showUpgrade = true } label: {
                    LockedFeatureRow(
                        iconName: "arrow.down.doc.fill",
                        iconColor: AppColors.accent,
                        title: "Export Full Backup",
                        subtitle: "Pro feature — upgrade to export your data"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exportFullBackupButton")
            }
        } header: {
            Text("Export")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var importSection: some View {
        Section {
            if proManager.isPro {
                Button {
                    showingFileImporter = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Backup")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Restore from a .thelogger backup file")
                                .font(.system(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("importBackupButton")
            } else {
                Button { showUpgrade = true } label: {
                    LockedFeatureRow(
                        iconName: "square.and.arrow.down.fill",
                        iconColor: .green,
                        title: "Import Backup",
                        subtitle: "Pro feature — upgrade to restore your data"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("importBackupButton")
            }
        } header: {
            Text("Import")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Full backups include all workouts, templates, exercise settings, and personal records.", systemImage: "info.circle")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                Label("Weights are stored in lbs internally and converted on display.", systemImage: "scalemass")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                Label("Importing skips duplicate workouts automatically.", systemImage: "doc.on.doc")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Export

    private func exportFullBackup() {
        isExporting = true
        let workouts = allWorkouts
        let memories = (try? modelContext.fetch(FetchDescriptor<ExerciseMemory>())) ?? []
        let records = (try? modelContext.fetch(FetchDescriptor<PersonalRecord>())) ?? []

        let jsonData = WorkoutDataExporter.generateJSON(workouts: workouts, memories: memories, records: records)

        let dateStr = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .prefix(10)
        let fileName = "TheLogger_Backup_\(dateStr).thelogger"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try jsonData.write(to: tempURL)
            shareURL = tempURL
            isExporting = false
            showingShareSheet = true
            Analytics.send(Analytics.Signal.backupExportedJSON, parameters: ["workoutCount": "\(workouts.count)"])
        } catch {
            isExporting = false
            debugLog("Error creating backup file: \(error)")
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let importResult = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
                self.importResult = importResult
                showingImportResult = true
                Analytics.send(Analytics.Signal.backupImported, parameters: [
                    "workoutsImported": "\(importResult.workoutsImported)",
                    "skipped": "\(importResult.skipped)"
                ])
            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

// MARK: - Export Row Label

private struct ExportRowLabel: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String?
    let showProgress: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showProgress {
                ProgressView()
            } else if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
    }
}

// MARK: - Locked Feature Row

private struct LockedFeatureRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(AppColors.accentGold.opacity(0.8))
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }
}
