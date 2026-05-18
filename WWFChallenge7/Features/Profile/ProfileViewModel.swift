//
//  ProfileViewModel.swift
//  WWFChallenge7
//
//  ViewModel for the visitor Profile — handles session state and
//  anonymous → registered upgrade.
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var showRegistration: Bool = false
    @Published var showLogin: Bool = false

    let session: UserSession

    init(session: UserSession) {
        self.session = session
    }

    var isAnonymous: Bool {
        session.isAnonymous
    }

    var displayName: String {
        session.username ?? session.email ?? "Visitatore Anonimo"
    }

    func register() async {
        await session.register(email: email, password: password)
        if session.loginError == nil {
            showRegistration = false
            email = ""
            password = ""
        }
    }

    func login() async {
        await session.login(email: email, password: password)
        if session.loginError == nil {
            showLogin = false
            email = ""
            password = ""
        }
    }

    func logout() async {
        await session.logout()
    }
}
