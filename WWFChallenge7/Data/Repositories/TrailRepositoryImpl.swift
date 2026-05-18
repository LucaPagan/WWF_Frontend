//
//  TrailRepositoryImpl.swift
//  WWFChallenge7
//
//  Data layer — concrete implementation using SwiftData (local-first)
//

import Foundation
import SwiftData

@ModelActor
final actor TrailRepositoryImpl: TrailRepository {

    func fetchActiveTrails() async throws -> [Trail] {
        let descriptor = FetchDescriptor<Trail>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\Trail.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchTrailById(_ id: UUID) async throws -> Trail? {
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    func fetchSteps(forTrailId id: UUID) async throws -> [TrailStep] {
        guard let trail = try await fetchTrailById(id) else { return [] }
        return trail.sortedSteps
    }
}
