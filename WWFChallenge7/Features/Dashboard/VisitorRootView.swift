//
//  VisitorRootView.swift
//  WWFChallenge7
//
//  Root tab view — uses UserSession instead of the old ManagerSession.
//

import SwiftUI

struct VisitorRootView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var gamificationService: GamificationService
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences
    @State private var selectedTab: Int = 0
    @ObservedObject private var localizer = LocalizationManager.shared
    
    @State private var unlockQueue: [ProfileUnlock] = []
    @State private var currentUnlock: ProfileUnlock?

    var body: some View {
        ZStack {
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    DashboardView()
                case 1:
                    EventListView()
                case 2:
                    ProfileView()
                default:
                    DashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar over the content
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .sheet(item: $currentUnlock, onDismiss: showNextUnlockIfNeeded) { unlock in
            UnlockCelebrationView(unlock: unlock, kidsMode: accessibilityPreferences.kidsMode)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: gamificationService.latestRewards) { _, rewards in
            enqueueUnlocks(rewards.map { ProfileUnlock(title: $0.title, detail: $0.detail) })
        }
        .onChange(of: gamificationService.latestLevelUp) { _, level in
            guard let level else { return }
            enqueueUnlocks([ProfileUnlock(title: "Nuovo livello", detail: level.title)])
        }
        .onAppear {
            gamificationService.flushDeferredRewards()
        }
    }
    
    private func enqueueUnlocks(_ unlocks: [ProfileUnlock]) {
        guard !unlocks.isEmpty else { return }
        unlockQueue.append(contentsOf: unlocks)
        if currentUnlock == nil {
            showNextUnlockIfNeeded()
        }
    }

    private func showNextUnlockIfNeeded() {
        guard currentUnlock == nil || !unlockQueue.isEmpty else { return }
        guard !unlockQueue.isEmpty else {
            currentUnlock = nil
            return
        }
        currentUnlock = unlockQueue.removeFirst()
        accessibilityPreferences.triggerNotificationHaptic(type: .success)
    }
}
