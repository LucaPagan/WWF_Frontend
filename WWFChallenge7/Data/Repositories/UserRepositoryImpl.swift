//
//  UserRepositoryImpl.swift
//  WWFChallenge7
//
//  Data layer — handles user profile creation and sync with Supabase users table.
//

import Foundation
import SwiftData

@ModelActor
final actor UserRepositoryImpl: UserRepository {

    func getOrCreateProfile(deviceId: String) async throws -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let profile = UserProfile(deviceId: deviceId)
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }

    func updateProfile(_ profile: UserProfile) async throws {
        profile.updatedAt = Date()
        try modelContext.save()
    }

    func registerUser(email: String, password: String, deviceId: String) async throws {
        // 1. Sign up via Supabase Auth
        try await SupabaseConfig.shared.signUp(email: email, password: password)

        // 2. Update local profile
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        if let profile = try modelContext.fetch(descriptor).first {
            profile.isAnonymous = false
            profile.email = email
            profile.updatedAt = Date()
            try modelContext.save()
        }
    }
}
