//
//  UpgradeView.swift
//  TheLogger
//
//  Paywall sheet — shown when a free user hits a Pro feature gate.
//

import SwiftUI
import RevenueCat

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProManager.self) private var proManager

    @State private var offering: Offering?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var proPackage: Package? {
        offering?.availablePackages.first { $0.packageType == .monthly }
        ?? offering?.availablePackages.first
    }

    private var priceText: String {
        proPackage.map { "\($0.storeProduct.localizedPriceString)/month" }
        ?? "$6.99/month"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    headerSection

                    // Feature list
                    featuresSection

                    // CTA
                    ctaSection

                    // Restore
                    restoreButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(AppColors.background)
            .navigationTitle("TheLogger Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
        .presentationBackground(AppColors.background)
        .task { await loadOffering() }
        .onChange(of: proManager.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppColors.accentGold)
            }
            .padding(.top, 12)

            Text("Unlock Everything")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.primary)

            Text("Go Pro to remove limits and access premium features.")
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 12) {
            ProFeatureRow(
                icon: "camera.fill",
                iconColor: AppColors.accent,
                title: "Unlimited Camera Sessions",
                subtitle: "Count reps hands-free — no monthly cap"
            )
            ProFeatureRow(
                icon: "square.and.arrow.up.fill",
                iconColor: .purple,
                title: "Unlimited Share Cards",
                subtitle: "Share every set as a skeleton story"
            )
            ProFeatureRow(
                icon: "trophy.fill",
                iconColor: AppColors.accentGold,
                title: "Full Achievements",
                subtitle: "All \(AchievementManager.definitions.count) achievements unlocked"
            )
            ProFeatureRow(
                icon: "externaldrive.fill",
                iconColor: .green,
                title: "Data Export",
                subtitle: "CSV and full JSON backup of all your workouts"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - CTA

    private var ctaSection: some View {
        Button {
            Task { await purchase() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    VStack(spacing: 2) {
                        Text("Subscribe — \(priceText)")
                            .font(.system(.body, weight: .bold))
                        Text("Cancel anytime")
                            .font(.system(.caption2, weight: .medium))
                            .opacity(0.75)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(AppColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPurchasing || isRestoring)
        .accessibilityIdentifier("upgradeSubscribeButton")
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            Group {
                if isRestoring {
                    ProgressView()
                        .tint(.secondary)
                } else {
                    Text("Restore Purchases")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(isPurchasing || isRestoring)
        .accessibilityIdentifier("upgradeRestoreButton")
    }

    // MARK: - Actions

    private func loadOffering() async {
        do {
            offering = try await Purchases.shared.offerings().current
        } catch {
            debugLog("[UpgradeView] Failed to load offering: \(error)")
        }
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await proManager.purchase()
        } catch ErrorCode.purchaseCancelledError {
            // User cancelled — no error to show
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await proManager.restore()
            if !proManager.isPro {
                errorMessage = "No active subscription found for this Apple ID."
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Pro Feature Row

private struct ProFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.accent.opacity(0.7))
                .font(.system(size: 18))
        }
    }
}
