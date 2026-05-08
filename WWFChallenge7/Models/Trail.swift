import Foundation
import SwiftData

@Model
final class Trail {
    var id: UUID
    var name: String
    var trailDescription: String
    var difficulty: TrailDifficulty
    var estimatedMinutes: Int
    var steps: [TrailStep]       // ordinati per orderIndex
    var isActive: Bool           // visibile ai visitatori

    init(
        name: String,
        description: String,
        difficulty: TrailDifficulty = .easy,
        estimatedMinutes: Int = 60
    ) {
        self.id = UUID()
        self.name = name
        self.trailDescription = description
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.steps = []
        self.isActive = false
    }

    // Step corrente durante la navigazione (il primo non ancora completato)
    func currentStep(completedPOIIds: Set<UUID>) -> TrailStep? {
        steps
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { step in
                guard let poi = step.poi else { return false }
                return !completedPOIIds.contains(poi.id)
            }
    }

    var sortedSteps: [TrailStep] {
        steps.sorted { $0.orderIndex < $1.orderIndex }
    }
}

enum TrailDifficulty: String, Codable, CaseIterable {
    case easy     = "Facile"
    case medium   = "Medio"
    case hard     = "Difficile"

    var color: String {
        switch self {
        case .easy:   return "#2E7D32"
        case .medium: return "#F57F17"
        case .hard:   return "#C62828"
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "figure.walk"
        case .medium: return "figure.hiking"
        case .hard:   return "mountain.2.fill"
        }
    }
}