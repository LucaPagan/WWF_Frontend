//
//  Trail.swift
//  WWFChallenge7
//
//  SwiftData entity — mirrors Supabase table: public.paths
//  Identical schema to GestionaleWWFIpad/Domain/Entities/Trail.swift
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Trail: @unchecked Sendable {
    var id: UUID
    var name: String
    var trailDescription: String
    var isActive: Bool
    var difficultyRawValue: String?
    var estimatedMinutes: Int?
    var coverImageURL: String?

    var steps: [TrailStep]
    var startPOIId: UUID?

    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    @Transient var difficulty: TrailDifficulty? {
        get { difficultyRawValue.flatMap { TrailDifficulty(rawValue: $0) } }
        set { difficultyRawValue = newValue?.rawValue }
    }

    @Transient var localizedName: String {
        LocalizationManager.shared.localizedField(table: "paths", recordId: id, fieldName: "name", fallback: name)
    }

    @Transient var localizedDescription: String {
        LocalizationManager.shared.localizedField(table: "paths", recordId: id, fieldName: "description", fallback: trailDescription)
    }


    init(
        name: String,
        description: String,
        isActive: Bool = false,
        difficulty: TrailDifficulty? = .easy,
        estimatedMinutes: Int? = 60,
        coverImageURL: String? = nil,
        startPOIId: UUID? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.name = name
        self.trailDescription = description
        self.isActive = isActive
        self.difficultyRawValue = difficulty?.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.coverImageURL = coverImageURL
        self.steps = []
        self.startPOIId = startPOIId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    var sortedSteps: [TrailStep] {
        steps.sorted { $0.stepOrder < $1.stepOrder }
    }

    func currentStep(completedPOIIds: Set<UUID>) -> TrailStep? {
        sortedSteps.first { step in
            guard let poi = step.poi else { return false }
            return !completedPOIIds.contains(poi.id)
        }
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["description"] as? String { trailDescription = d }
        if let active = data["is_active"] as? Bool { isActive = active }
        if let diff = data["difficulty"] as? String { difficultyRawValue = diff }
        estimatedMinutes = data["estimated_minutes"] as? Int
        coverImageURL = data["cover_image_url"] as? String
        if let spid = data["start_poi_id"] as? String {
            startPOIId = UUID(uuidString: spid)
        }
        needsSync = false
    }

    // MARK: - Backward Compatibility for Visitor App
    var startX: Double {
        sortedSteps.first?.poi?.x ?? 0.1
    }
    
    var startY: Double {
        sortedSteps.first?.poi?.y ?? 0.9
    }
    
    var startPointName: String {
        sortedSteps.first?.poi?.localizedName ?? LocalizationManager.shared.localizedString(for: "start_point_fallback")
    }
    
    var startPointDescription: String {
        sortedSteps.first?.poi?.localizedDescription ?? LocalizationManager.shared.localizedString(for: "start_point_fallback_desc")
    }
}

enum TrailDifficulty: String, Codable, CaseIterable {
    case easy   = "easy"
    case medium = "medium"
    case hard   = "hard"

    var displayName: String {
        switch self {
        case .easy:   return "Facile"
        case .medium: return "Medio"
        case .hard:   return "Difficile"
        }
    }

    var color: Color {
        switch self {
        case .easy:   return WWFStyle.Colors.green
        case .medium: return WWFStyle.Colors.warning
        case .hard:   return WWFStyle.Colors.danger
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "figure.walk"
        case .medium: return "figure.hiking"
        case .hard:   return "mountain.2.fill"
        }
    }

    var supabaseValue: String { rawValue }

    nonisolated static func fromSupabase(_ value: String) -> TrailDifficulty? {
        TrailDifficulty(rawValue: value)
    }
}
