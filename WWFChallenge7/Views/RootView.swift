//
//  RootView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import SwiftData

struct RootView: View {
    @StateObject private var managerSession = ManagerSession()
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if managerSession.isLoggedIn {
                ManagerRootView()
                    .environmentObject(managerSession)
            } else {
                VisitorRootView()
                    .environmentObject(managerSession)
            }
        }
        .onAppear {
            DataService.seedIfNeeded(context: context)
        }
    }
}