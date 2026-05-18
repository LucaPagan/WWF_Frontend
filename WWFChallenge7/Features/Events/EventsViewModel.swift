//
//  EventsViewModel.swift
//  WWFChallenge7
//
//  ViewModel for EventList and EventDetail — MVVM pattern.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class EventsViewModel: ObservableObject {

    @Published var events: [Event] = []
    @Published var selectedEvent: Event?
    @Published var isLoading: Bool = false

    private var modelContainer: ModelContainer?

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        loadEvents()
    }

    func loadEvents() {
        guard let container = modelContainer else { return }
        isLoading = true

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\Event.date)]
        )
        events = (try? context.fetch(descriptor)) ?? []
        isLoading = false
    }

    var todayEvents: [Event] {
        events.filter { $0.isToday }
    }

    var upcomingEvents: [Event] {
        events.filter { $0.isUpcoming && !$0.isToday }
    }

    func selectEvent(_ event: Event) {
        selectedEvent = event
    }

    func clearSelection() {
        selectedEvent = nil
    }
}
