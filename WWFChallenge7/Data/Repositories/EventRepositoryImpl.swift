//
//  EventRepositoryImpl.swift
//  WWFChallenge7
//
//  Data layer — concrete implementation using SwiftData (local-first)
//

import Foundation
import SwiftData

@ModelActor
final actor EventRepositoryImpl: EventRepository {

    func fetchActiveEvents() async throws -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\Event.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchEventById(_ id: UUID) async throws -> Event? {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }
}
