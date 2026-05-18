//
//  UserProfile.swift
//  WWFChallenge7
//
//  SwiftData entity — mirrors Supabase table: public.users
//  Represents the visitor's profile (anonymous or registered).
//

import Foundation
import SwiftData

@Model
final class UserProfile: @unchecked Sendable {
    var id: UUID
    var deviceId: String
    var isAnonymous: Bool
    var email: String?
    var username: String?
    var avatarURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        deviceId: String,
        isAnonymous: Bool = true,
        email: String? = nil,
        username: String? = nil,
        avatarURL: String? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.deviceId = deviceId
        self.isAnonymous = isAnonymous
        self.email = email
        self.username = username
        self.avatarURL = avatarURL
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let a = data["is_anonymous"] as? Bool { isAnonymous = a }
        email = data["email"] as? String
        username = data["username"] as? String
        avatarURL = data["avatar_url"] as? String
    }
}
