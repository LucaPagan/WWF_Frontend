import Foundation
import SwiftData

enum LocalGamificationSyncStatus: String, Codable, CaseIterable {
    case pending
    case synced
    case rejected
    case localOnly = "local_only"
}

enum LocalValidationStatus: String, Codable, CaseIterable {
    case accepted
    case rejected
    case ignored
    case warning
}

@Model
final class LocalGamificationRule {
    var id: UUID
    var title: String
    var ruleDescription: String?
    var triggerType: String
    var conditionsData: Data
    var rewardData: Data
    var audience: String
    var isHidden: Bool
    var isRepeatable: Bool
    var cooldownSeconds: Int?
    var startsAt: Date?
    var endsAt: Date?
    var priority: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        triggerType: String,
        conditions: [String: Any] = [:],
        reward: [String: Any] = [:],
        audience: String = "all",
        isHidden: Bool = false,
        isRepeatable: Bool = false,
        cooldownSeconds: Int? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        priority: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.ruleDescription = description
        self.triggerType = triggerType
        self.conditionsData = Self.encodeJSON(conditions)
        self.rewardData = Self.encodeJSON(reward)
        self.audience = audience
        self.isHidden = isHidden
        self.isRepeatable = isRepeatable
        self.cooldownSeconds = cooldownSeconds
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.priority = priority
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    @Transient var conditions: [String: Any] {
        Self.decodeJSON(conditionsData)
    }

    @Transient var reward: [String: Any] {
        Self.decodeJSON(rewardData)
    }

    func updateFromRemote(_ data: [String: Any]) {
        title = data["title"] as? String ?? title
        ruleDescription = data["description"] as? String
        triggerType = data["trigger_type"] as? String ?? triggerType
        if let conditions = data["conditions_json"] as? [String: Any] {
            conditionsData = Self.encodeJSON(conditions)
        }
        if let reward = data["reward_json"] as? [String: Any] {
            rewardData = Self.encodeJSON(reward)
        }
        audience = data["audience"] as? String ?? audience
        isHidden = data["is_hidden"] as? Bool ?? isHidden
        isRepeatable = data["is_repeatable"] as? Bool ?? isRepeatable
        cooldownSeconds = data["cooldown_seconds"] as? Int
        startsAt = LocalGamificationDateParser.date(from: data["starts_at"])
        endsAt = LocalGamificationDateParser.date(from: data["ends_at"])
        priority = data["priority"] as? Int ?? priority
        isActive = data["is_active"] as? Bool ?? isActive
        updatedAt = LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
    }

    static func encodeJSON(_ value: [String: Any]) -> Data {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return Data("{}".utf8)
        }
        return data
    }

    static func decodeJSON(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

@Model
final class LocalGamificationLevel {
    var id: UUID
    var levelNumber: Int
    var title: String
    var levelDescription: String?
    var requiredXP: Int
    var iconName: String?
    var imageURL: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        levelNumber: Int,
        title: String,
        description: String? = nil,
        requiredXP: Int,
        iconName: String? = nil,
        imageURL: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.levelNumber = levelNumber
        self.title = title
        self.levelDescription = description
        self.requiredXP = requiredXP
        self.iconName = iconName
        self.imageURL = imageURL
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func updateFromRemote(_ data: [String: Any]) {
        levelNumber = data["level_number"] as? Int ?? levelNumber
        title = data["title"] as? String ?? title
        levelDescription = data["description"] as? String
        requiredXP = data["required_xp"] as? Int ?? requiredXP
        iconName = data["icon_name"] as? String
        imageURL = data["image_url"] as? String
        isActive = data["is_active"] as? Bool ?? isActive
        updatedAt = LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
    }
}

@Model
final class LocalUserGamificationStats {
    var id: UUID
    var userId: UUID?
    var deviceId: String
    var xpTotal: Int
    var currentLevel: Int
    var currentRank: String
    var poisVisitedCount: Int
    var trailsCompletedCount: Int
    var eventsCompletedCount: Int
    var speciesUnlockedCount: Int
    var badgesUnlockedCount: Int
    var lastActivityAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(deviceId: String, userId: UUID? = nil, fixedID: UUID? = nil) {
        self.id = fixedID ?? UUID()
        self.userId = userId
        self.deviceId = deviceId
        self.xpTotal = 0
        self.currentLevel = 1
        self.currentRank = "Visitatore"
        self.poisVisitedCount = 0
        self.trailsCompletedCount = 0
        self.eventsCompletedCount = 0
        self.speciesUnlockedCount = 0
        self.badgesUnlockedCount = 0
        self.lastActivityAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) { id = remoteId }
        if let userIdStr = data["user_id"] as? String { userId = UUID(uuidString: userIdStr) }
        deviceId = data["device_id"] as? String ?? deviceId
        xpTotal = data["xp_total"] as? Int ?? xpTotal
        currentLevel = data["current_level"] as? Int ?? currentLevel
        currentRank = data["current_rank"] as? String ?? currentRank
        poisVisitedCount = data["pois_visited_count"] as? Int ?? poisVisitedCount
        trailsCompletedCount = data["trails_completed_count"] as? Int ?? trailsCompletedCount
        eventsCompletedCount = data["events_completed_count"] as? Int ?? eventsCompletedCount
        speciesUnlockedCount = data["species_unlocked_count"] as? Int ?? speciesUnlockedCount
        badgesUnlockedCount = data["badges_unlocked_count"] as? Int ?? badgesUnlockedCount
        lastActivityAt = LocalGamificationDateParser.date(from: data["last_activity_at"])
        updatedAt = LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
    }
}

@Model
final class LocalBadge {
    var id: UUID
    var name: String
    var badgeDescription: String?
    var iconName: String?
    var imageURL: String?
    var criteriaData: Data?
    var category: String
    var rarity: String
    var isHidden: Bool
    var unlockHint: String?
    var sortOrder: Int
    var xpReward: Int
    var relatedSpeciesId: UUID?
    var relatedPathId: UUID?
    var relatedEventId: UUID?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.badgeDescription = description
        self.iconName = nil
        self.imageURL = nil
        self.criteriaData = nil
        self.category = "exploration"
        self.rarity = "common"
        self.isHidden = false
        self.unlockHint = nil
        self.sortOrder = 0
        self.xpReward = 0
        self.relatedSpeciesId = nil
        self.relatedPathId = nil
        self.relatedEventId = nil
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateFromRemote(_ data: [String: Any]) {
        name = data["title"] as? String ?? data["name"] as? String ?? name
        badgeDescription = data["description"] as? String
        iconName = data["icon_name"] as? String ?? data["image_url"] as? String
        imageURL = data["image_url"] as? String
        if let criteria = data["criteria"] as? [String: Any] {
            criteriaData = LocalGamificationRule.encodeJSON(criteria)
        }
        category = data["category"] as? String ?? category
        rarity = data["rarity"] as? String ?? rarity
        isHidden = data["is_hidden"] as? Bool ?? isHidden
        unlockHint = data["unlock_hint"] as? String
        sortOrder = data["sort_order"] as? Int ?? sortOrder
        xpReward = data["xp_reward"] as? Int ?? xpReward
        relatedSpeciesId = UUID.from(data["related_species_id"])
        relatedPathId = UUID.from(data["related_path_id"])
        relatedEventId = UUID.from(data["related_event_id"])
        isActive = data["is_active"] as? Bool ?? isActive
        updatedAt = LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
    }
}

@Model
final class LocalUserBadge {
    var id: UUID
    var userId: UUID?
    var deviceId: String
    var badgeId: UUID
    var unlockedAt: Date
    var unlockSource: String?
    var syncedAt: Date?
    var syncStatusRawValue: String

    @Transient var syncStatus: LocalGamificationSyncStatus {
        get { LocalGamificationSyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }

    init(deviceId: String, badgeId: UUID, userId: UUID? = nil, source: String? = nil, fixedID: UUID? = nil) {
        self.id = fixedID ?? UUID()
        self.userId = userId
        self.deviceId = deviceId
        self.badgeId = badgeId
        self.unlockedAt = Date()
        self.unlockSource = source
        self.syncedAt = nil
        self.syncStatusRawValue = LocalGamificationSyncStatus.pending.rawValue
    }
}

@Model
final class LocalSpecies {
    var id: UUID
    var name: String
    var scientificName: String?
    var speciesDescription: String
    var descriptionKids: String?
    var descriptionEasyRead: String?
    var category: String
    var rarity: String
    var habitat: String?
    var imageURL: String?
    var iconName: String?
    var relatedPOIId: UUID?
    var relatedPathId: UUID?
    var unlockCriteriaData: Data?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, description: String, category: String = "fauna") {
        self.id = id
        self.name = name
        self.scientificName = nil
        self.speciesDescription = description
        self.descriptionKids = nil
        self.descriptionEasyRead = nil
        self.category = category
        self.rarity = "common"
        self.habitat = nil
        self.imageURL = nil
        self.iconName = nil
        self.relatedPOIId = nil
        self.relatedPathId = nil
        self.unlockCriteriaData = nil
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateFromRemote(_ data: [String: Any]) {
        name = data["name"] as? String ?? name
        scientificName = data["scientific_name"] as? String
        speciesDescription = data["description"] as? String ?? speciesDescription
        descriptionKids = data["description_kids"] as? String
        descriptionEasyRead = data["description_easy_read"] as? String
        category = data["category"] as? String ?? category
        rarity = data["rarity"] as? String ?? rarity
        habitat = data["habitat"] as? String
        imageURL = data["image_url"] as? String
        iconName = data["icon_name"] as? String
        relatedPOIId = UUID.from(data["related_poi_id"])
        relatedPathId = UUID.from(data["related_path_id"])
        if let criteria = data["unlock_criteria_json"] as? [String: Any] {
            unlockCriteriaData = LocalGamificationRule.encodeJSON(criteria)
        }
        isActive = data["is_active"] as? Bool ?? isActive
        updatedAt = LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
    }
}

@Model
final class LocalUserSpecies {
    var id: UUID
    var userId: UUID?
    var deviceId: String
    var speciesId: UUID
    var unlockedAt: Date
    var unlockSource: String?
    var sourcePOIId: UUID?
    var sourcePathId: UUID?
    var syncedAt: Date?
    var syncStatusRawValue: String

    @Transient var syncStatus: LocalGamificationSyncStatus {
        get { LocalGamificationSyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }

    init(deviceId: String, speciesId: UUID, userId: UUID? = nil, source: String? = nil, sourcePOIId: UUID? = nil, sourcePathId: UUID? = nil, fixedID: UUID? = nil) {
        self.id = fixedID ?? UUID()
        self.userId = userId
        self.deviceId = deviceId
        self.speciesId = speciesId
        self.unlockedAt = Date()
        self.unlockSource = source
        self.sourcePOIId = sourcePOIId
        self.sourcePathId = sourcePathId
        self.syncedAt = nil
        self.syncStatusRawValue = LocalGamificationSyncStatus.pending.rawValue
    }
}

@Model
final class LocalGamificationEventLog {
    var id: UUID
    var triggerType: String
    var entityType: String?
    var entityId: UUID?
    var payloadData: Data
    var occurredAt: Date
    var syncStatusRawValue: String
    var syncedAt: Date?
    var rejectionReason: String?

    @Transient var syncStatus: LocalGamificationSyncStatus {
        get { LocalGamificationSyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }

    @Transient var payload: [String: Any] {
        LocalGamificationRule.decodeJSON(payloadData)
    }

    init(triggerType: String, entityType: String? = nil, entityId: UUID? = nil, payload: [String: Any] = [:], fixedID: UUID? = nil) {
        self.id = fixedID ?? UUID()
        self.triggerType = triggerType
        self.entityType = entityType
        self.entityId = entityId
        self.payloadData = LocalGamificationRule.encodeJSON(payload)
        self.occurredAt = Date()
        self.syncStatusRawValue = LocalGamificationSyncStatus.pending.rawValue
        self.syncedAt = nil
        self.rejectionReason = nil
    }
}

@Model
final class LocalValidationLog {
    var id: UUID
    var eventType: String
    var entityType: String?
    var entityId: UUID?
    var statusRawValue: String
    var reason: String?
    var payloadData: Data?
    var createdAt: Date

    @Transient var status: LocalValidationStatus {
        get { LocalValidationStatus(rawValue: statusRawValue) ?? .accepted }
        set { statusRawValue = newValue.rawValue }
    }

    init(eventType: String, entityType: String? = nil, entityId: UUID? = nil, status: LocalValidationStatus, reason: String? = nil, payload: [String: Any]? = nil) {
        self.id = UUID()
        self.eventType = eventType
        self.entityType = entityType
        self.entityId = entityId
        self.statusRawValue = status.rawValue
        self.reason = reason
        self.payloadData = payload.map { LocalGamificationRule.encodeJSON($0) }
        self.createdAt = Date()
    }
}

@Model
final class LocalGamificationRuleAward {
    var id: UUID
    var ruleId: UUID
    var dedupeKey: String
    var awardedAt: Date

    init(ruleId: UUID, dedupeKey: String) {
        self.id = UUID()
        self.ruleId = ruleId
        self.dedupeKey = dedupeKey
        self.awardedAt = Date()
    }
}

enum LocalGamificationDateParser {
    static func date(from value: Any?) -> Date? {
        if let date = value as? Date { return date }
        guard let string = value as? String, !string.isEmpty else { return nil }
        if let date = ISO8601DateFormatter.gamification.date(from: string) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }
        return nil
    }
}

private extension ISO8601DateFormatter {
    static let gamification: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension UUID {
    static func from(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }
}
