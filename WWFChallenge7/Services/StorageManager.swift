//
//  StorageService.swift
//  WWFChallenge7
//
//  Storage service for the User (visitor) module.
//  Read-only: downloads only, no uploads.
//

import Foundation

protocol StorageService: Sendable {
    func downloadData(from url: String) async throws -> Data
}

final class StorageManager: StorageService {
    static let shared = StorageManager()

    private init() {}

    func downloadData(from url: String) async throws -> Data {
        return try await SupabaseConfig.shared.downloadFile(from: url)
    }
}
