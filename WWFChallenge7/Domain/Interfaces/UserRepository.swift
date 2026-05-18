//
//  UserRepository.swift
//  WWFChallenge7
//
//  Domain interface for user/visitor data operations.
//

import Foundation

protocol UserRepository: Sendable {
    func getOrCreateProfile(deviceId: String) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws
    func registerUser(email: String, password: String, deviceId: String) async throws
}
