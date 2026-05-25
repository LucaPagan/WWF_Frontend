//
//  UserSession.swift
//  WWFChallenge7
//
//  Manages visitor session state:
//  - Anonymous users identified by device_id (UUID stored in UserDefaults)
//  - Registered users authenticated via Supabase Auth
//  - Supports upgrade from anonymous → registered without data loss
//
//  Replaces the old ManagerSession stub in the User app.
//

import Foundation
import Combine

@MainActor
final class UserSession: ObservableObject {

    // MARK: - Published State

    @Published var isAnonymous: Bool = true
    @Published var isLoading: Bool = false
    @Published var email: String?
    @Published var username: String?
    @Published var loginError: String?

    // MARK: - Device Identity

    /// Persistent device UUID for anonymous session tracking.
    /// Used as the `device_id` claim in Supabase RLS policies.
    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: "wwf_device_id") {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "wwf_device_id")
        return newId
    }

    var deviceSecret: String {
        if let existing = KeychainHelper.load(key: "wwf_device_secret") {
            return existing
        }
        let secret = UUID().uuidString + "-" + UUID().uuidString
        KeychainHelper.save(key: "wwf_device_secret", value: secret)
        return secret
    }

    // MARK: - Init

    init() {
        // Restore any cached session
        if let cachedEmail = UserDefaults.standard.string(forKey: "wwf_user_email") {
            self.email = cachedEmail
            self.isAnonymous = false
            self.username = UserDefaults.standard.string(forKey: "wwf_user_username")
        }
    }

    // MARK: - Anonymous Session

    /// Ensures a device-based user profile exists on the backend.
    /// Called on every app launch.
    func ensureAnonymousProfile() async {
        _ = deviceId
        try? await ensureGamificationDeviceRegistered()
    }

    func ensureGamificationDeviceRegistered() async throws {
        _ = try await SupabaseConfig.shared.rpc("register_gamification_device", params: [
            "p_device_id": deviceId,
            "p_device_secret": deviceSecret
        ])
    }

    // MARK: - Register (Anonymous → Registered)

    /// Upgrades the anonymous user to a registered account.
    /// Local SwiftData data is preserved because the device_id stays the same.
    func register(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Inserisci email e password."
            return
        }

        isLoading = true
        loginError = nil

        do {
            try await SupabaseConfig.shared.signUp(email: email, password: password)
            self.email = email
            self.isAnonymous = false
            UserDefaults.standard.set(email, forKey: "wwf_user_email")
            NotificationCenter.default.post(name: .wwfUserDidRegister, object: nil)
        } catch {
            loginError = "Registrazione fallita: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Inserisci email e password."
            return
        }

        isLoading = true
        loginError = nil

        do {
            try await SupabaseConfig.shared.signIn(email: email, password: password)
            self.email = email
            self.isAnonymous = false
            UserDefaults.standard.set(email, forKey: "wwf_user_email")
            NotificationCenter.default.post(name: .wwfUserDidRegister, object: nil)
        } catch {
            loginError = "Login fallito: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() async {
        try? await SupabaseConfig.shared.signOut()
        email = nil
        username = nil
        isAnonymous = true
        UserDefaults.standard.removeObject(forKey: "wwf_user_email")
        UserDefaults.standard.removeObject(forKey: "wwf_user_username")
    }

    // MARK: - Restore Session

    func restoreSession() async {
        if let session = await SupabaseConfig.shared.currentSession() {
            email = session.user.email
            isAnonymous = false
            NotificationCenter.default.post(name: .wwfUserDidRegister, object: nil)
        }
    }
}
