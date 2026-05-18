//
//  VisitorRootView.swift
//  WWFChallenge7
//
//  Root tab view — uses UserSession instead of the old ManagerSession.
//

import SwiftUI

struct VisitorRootView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var selectedTab: Int = 0
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(localizer.localizedString(for: "explore"), systemImage: "map.fill")
                }
                .tag(0)

            EventListView()
                .tabItem {
                    Label(localizer.localizedString(for: "events"), systemImage: "calendar.badge.clock")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label(localizer.localizedString(for: "profile"), systemImage: "person.fill")
                }
                .tag(2)
        }
        .accentColor(WWFStyle.Colors.green)
    }
}
