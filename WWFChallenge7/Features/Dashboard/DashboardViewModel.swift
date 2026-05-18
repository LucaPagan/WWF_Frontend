//
//  DashboardViewModel.swift
//  WWFChallenge7
//
//  ViewModel for the visitor Dashboard — MVVM pattern.
//  Isolates all data fetching and business logic from DashboardView.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var trails: [Trail] = []
    @Published var selectedTrail: Trail?
    @Published var isLoading: Bool = false

    private var modelContainer: ModelContainer?

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        loadTrails()
    }

    func loadTrails() {
        guard let container = modelContainer else { return }
        isLoading = true

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Trail>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\Trail.name)]
        )
        trails = (try? context.fetch(descriptor)) ?? []
        isLoading = false
    }

    func selectTrail(_ trail: Trail) {
        selectedTrail = trail
    }

    func clearSelection() {
        selectedTrail = nil
    }
}
