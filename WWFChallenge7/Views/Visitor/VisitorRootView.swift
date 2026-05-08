//
//  VisitorRootView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

struct VisitorRootView: View {
    @EnvironmentObject var managerSession: ManagerSession
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Esplora", systemImage: "map.fill")
                }
                .tag(0)

            EventListView()
                .tabItem {
                    Label("Eventi", systemImage: "calendar.badge.clock")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profilo", systemImage: "person.fill")
                }
                .tag(2)

            ManagerLoginView()
                .tabItem {
                    Label("Gestione", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(Color("WWFGreen"))
    }
}
