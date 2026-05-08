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

            ProfileView()
                .tabItem {
                    Label("Profilo", systemImage: "person.fill")
                }
                .tag(1)

            // Accesso nascosto al gestionale — tap 5 volte sull'icona impostazioni
            ManagerLoginView()
                .tabItem {
                    Label("Gestione", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(Color("WWFGreen"))
    }
}