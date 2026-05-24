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
    }
}
