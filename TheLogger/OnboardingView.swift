//
//  OnboardingView.swift
//  TheLogger
//
//  Simple 3-screen onboarding flow for new users
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        pageIndex: 0,
                        currentPage: currentPage,
                        icon: "figure.strengthtraining.traditional",
                        iconColor: AppColors.accent,
                        title: "Track Your Lifts",
                        description: "Log exercises, sets, and weights with minimal friction. Built for speed in the gym."
                    )
                    .tag(0)
                    
                    OnboardingPage(
                        pageIndex: 1,
                        currentPage: currentPage,
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: AppColors.accentGold,
                        title: "See Your Progress",
                        description: "View personal records and track your gains over time. Automatic progress comparison."
                    )
                    .tag(1)
                    
                    OnboardingPage(
                        pageIndex: 2,
                        currentPage: currentPage,
                        icon: "lock.shield.fill",
                        iconColor: AppColors.accent,
                        title: "Your Data, Your Device",
                        description: "All data stays on your device. No accounts, no cloud, no tracking. Just you and your gains."
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? AppColors.accent : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.vertical, 24)
                
                // Action button
                Button {
                    if currentPage < 2 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < 2 ? "Continue" : "Get Started")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Skip button (only on first two screens)
                if currentPage < 2 {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 24)
                } else {
                    Spacer()
                        .frame(height: 44)
                }
            }
        }
    }
}

struct OnboardingPage: View {
    let pageIndex: Int
    let currentPage: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    @State private var iconAppeared = false
    @State private var titleAppeared = false
    @State private var descAppeared = false
    
    private var isSelected: Bool { currentPage == pageIndex }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .scaleEffect(iconAppeared ? 1 : 0.8)
            .opacity(iconAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: iconAppeared)
            .onAppear {
                iconAppeared = true
            }
            .onChange(of: currentPage) { _, _ in
                if currentPage != pageIndex { iconAppeared = false }
                else { iconAppeared = true }
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 6)
                    .animation(.easeOut(duration: 0.32), value: titleAppeared)
                
                Text(description)
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(descAppeared ? 1 : 0)
                    .offset(y: descAppeared ? 0 : 6)
                    .animation(.easeOut(duration: 0.32), value: descAppeared)
            }
            .padding(.horizontal, 32)
            .onAppear {
                titleAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { descAppeared = true }
            }
            .onChange(of: currentPage) { _, _ in
                if currentPage != pageIndex {
                    titleAppeared = false
                    descAppeared = false
                } else {
                    titleAppeared = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { descAppeared = true }
                }
            }
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}



