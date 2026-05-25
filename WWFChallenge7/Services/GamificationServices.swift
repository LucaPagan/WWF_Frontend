import Foundation
import SwiftData
import Combine
import CryptoKit

struct GamificationRewardSummary: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

struct TrailValidationResult {
    let accepted: Bool
    let reason: String?
    let completionPercent: Int
}

@MainActor
final class GamificationService: ObservableObject {
    @Published var latestRewards: [GamificationRewardSummary] = []
    @Published var latestLevelUp: LocalGamificationLevel?

    private var context: ModelContext?
    private var userSession: UserSession?
    private let ruleEvaluator = GamificationRuleEvaluator()
    private let syncService = GamificationSyncService()
    private let badgeUnlockService = BadgeUnlockService()
    private let speciesCollectionService = SpeciesCollectionService()
    private let xpLevelService = XPLevelService()
    private let trailValidator = TrailCompletionValidator()
    private let eventCompletionService = EventCompletionService()
    private var registrationObserver: NSObjectProtocol?

    func configure(with context: ModelContext, userSession: UserSession) {
        self.context = context
        self.userSession = userSession
        _ = xpLevelService.ensureStats(context: context, deviceId: userSession.deviceId)

        registrationObserver = NotificationCenter.default.addObserver(
            forName: .wwfUserDidRegister,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.migrateAnonymousToRegisteredAndSync()
            }
        }
    }

    func trailStarted(_ trail: Trail) {
        handleEvent(
            triggerType: "trail_started",
            entityType: "path",
            entityId: trail.id,
            payload: ["path_id": trail.id.uuidString]
        )
    }

    func poiScanned(poi: POI, trail: Trail, progress: LocalTrailProgress, visit: LocalPOIVisit) {
        handleEvent(
            triggerType: "poi_scanned",
            entityType: "poi",
            entityId: poi.id,
            payload: [
                "poi_id": poi.id.uuidString,
                "path_id": trail.id.uuidString,
                "scanned_at": ISO8601DateFormatter.gamificationString.string(from: visit.scannedAt),
                "validation_method": visit.sourceRawValue,
                "client_scan_id": visit.id.uuidString
            ]
        )
    }

    func trailCompleted(_ trail: Trail, progress: LocalTrailProgress) {
        guard let context else { return }
        let validation = trailValidator.validate(trail: trail, progress: progress, conditions: [:], context: context)
        context.insert(LocalValidationLog(
            eventType: "trail_completed",
            entityType: "path",
            entityId: trail.id,
            status: validation.accepted ? .accepted : .rejected,
            reason: validation.reason,
            payload: [
                "path_id": trail.id.uuidString,
                "completion_percent": validation.completionPercent
            ]
        ))

        guard validation.accepted else {
            try? context.save()
            return
        }

        handleEvent(
            triggerType: "trail_completed",
            entityType: "path",
            entityId: trail.id,
            payload: [
                "path_id": trail.id.uuidString,
                "completion_percent": validation.completionPercent
            ]
        )
        handleEvent(
            triggerType: "all_pois_in_trail_completed",
            entityType: "path",
            entityId: trail.id,
            payload: [
                "path_id": trail.id.uuidString,
                "completion_percent": validation.completionPercent
            ]
        )
    }

    func eventRegistered(_ event: Event) {
        handleEvent(
            triggerType: "event_registered",
            entityType: "event",
            entityId: event.id,
            payload: ["event_id": event.id.uuidString]
        )
    }

    func eventCompleted(_ event: Event, validationMethod: String, payload: String?) {
        guard let context else { return }
        let validation = eventCompletionService.validate(event: event, validationMethod: validationMethod, payload: payload)
        context.insert(LocalValidationLog(
            eventType: "event_completed",
            entityType: "event",
            entityId: event.id,
            status: validation.accepted ? .accepted : .rejected,
            reason: validation.reason,
            payload: [
                "event_id": event.id.uuidString,
                "validation_method": validationMethod,
                "validation_payload": payload ?? ""
            ]
        ))

        guard validation.accepted else {
            try? context.save()
            return
        }

        handleEvent(
            triggerType: "event_completed",
            entityType: "event",
            entityId: event.id,
            payload: [
                "event_id": event.id.uuidString,
                "completed_at": ISO8601DateFormatter.gamificationString.string(from: Date()),
                "validation_method": validationMethod,
                "validation_payload": payload ?? ""
            ]
        )
    }

    func audioGuideListened(content: Content) {
        handleEvent(
            triggerType: "audio_guide_listened",
            entityType: "content",
            entityId: content.id,
            payload: [
                "content_id": content.id.uuidString,
                "poi_id": content.poiId.uuidString
            ]
        )
    }

    func speciesUnlocked(_ speciesId: UUID, source: String, sourcePOIId: UUID? = nil, sourcePathId: UUID? = nil) {
        guard let context, let userSession else { return }
        if speciesCollectionService.unlockSpecies(
            context: context,
            deviceId: userSession.deviceId,
            speciesId: speciesId,
            source: source,
            sourcePOIId: sourcePOIId,
            sourcePathId: sourcePathId
        ) {
            handleEvent(
                triggerType: "species_unlocked",
                entityType: "species",
                entityId: speciesId,
                payload: ["species_id": speciesId.uuidString]
            )
        }
    }

    func syncPendingIfRegistered() async {
        guard let context, let userSession, !userSession.isAnonymous else { return }
        do {
            try await syncService.syncPending(context: context, userSession: userSession)
        } catch {
            // Keep offline-first state. Pending logs/progress remain queued.
        }
    }

    func migrateAnonymousToRegisteredAndSync() async {
        guard let context, let userSession else { return }
        let stats = xpLevelService.ensureStats(context: context, deviceId: userSession.deviceId)
        if let session = await SupabaseConfig.shared.currentSession(), let userId = UUID(uuidString: session.user.id) {
            stats.userId = userId
        }
        try? context.save()
        await syncPendingIfRegistered()
    }

    private func handleEvent(triggerType: String, entityType: String?, entityId: UUID?, payload: [String: Any]) {
        guard let context, let userSession else { return }

        let log = LocalGamificationEventLog(
            triggerType: triggerType,
            entityType: entityType,
            entityId: entityId,
            payload: payload
        )
        log.syncStatus = userSession.isAnonymous ? .localOnly : .pending
        context.insert(log)

        let rewards = ruleEvaluator.evaluate(
            triggerType: triggerType,
            entityType: entityType,
            entityId: entityId,
            payload: payload,
            isAnonymous: userSession.isAnonymous,
            context: context
        )

        var summaries: [GamificationRewardSummary] = []
        for reward in rewards {
            summaries.append(contentsOf: applyReward(reward, source: triggerType))
        }

        xpLevelService.refreshCounters(context: context, deviceId: userSession.deviceId)
        latestRewards = summaries
        try? context.save()

        if !userSession.isAnonymous {
            Task { await syncPendingIfRegistered() }
        }
    }

    private func applyReward(_ reward: [String: Any], source: String) -> [GamificationRewardSummary] {
        guard let context, let userSession else { return [] }
        var summaries: [GamificationRewardSummary] = []

        if let xp = reward["xp"] as? Int, xp > 0 {
            let levelUp = xpLevelService.awardXP(context: context, deviceId: userSession.deviceId, amount: xp, reason: source)
            summaries.append(GamificationRewardSummary(title: "+\(xp) XP", detail: "Progresso aggiornato"))
            if let levelUp {
                latestLevelUp = levelUp
                summaries.append(GamificationRewardSummary(title: "Nuovo livello", detail: levelUp.title))
            }
        }

        if let badgeId = UUID.fromGamificationValue(reward["badge_id"]),
           badgeUnlockService.unlockBadge(context: context, deviceId: userSession.deviceId, badgeId: badgeId, source: source) {
            summaries.append(GamificationRewardSummary(title: "Badge sbloccato", detail: badgeUnlockService.badgeName(context: context, badgeId: badgeId)))
            if let badge = badgeUnlockService.badge(context: context, badgeId: badgeId), badge.xpReward > 0 {
                _ = xpLevelService.awardXP(context: context, deviceId: userSession.deviceId, amount: badge.xpReward, reason: "badge_unlocked")
            }
            handleEvent(
                triggerType: "badge_unlocked",
                entityType: "badge",
                entityId: badgeId,
                payload: ["badge_id": badgeId.uuidString]
            )
        }

        if let speciesId = UUID.fromGamificationValue(reward["species_id"]),
           speciesCollectionService.unlockSpecies(context: context, deviceId: userSession.deviceId, speciesId: speciesId, source: source) {
            summaries.append(GamificationRewardSummary(title: "Specie sbloccata", detail: speciesCollectionService.speciesName(context: context, speciesId: speciesId)))
            handleEvent(
                triggerType: "species_unlocked",
                entityType: "species",
                entityId: speciesId,
                payload: ["species_id": speciesId.uuidString]
            )
        }

        if reward["level_check"] != nil {
            _ = xpLevelService.recalculateLevel(context: context, deviceId: userSession.deviceId)
        }

        if let profileTitle = reward["profile_title"] as? String, !profileTitle.isEmpty {
            summaries.append(GamificationRewardSummary(title: "Titolo profilo", detail: profileTitle))
        }

        if let collectionItem = reward["collection_item"] as? String, !collectionItem.isEmpty {
            summaries.append(GamificationRewardSummary(title: "Collezione", detail: collectionItem))
        }

        return summaries
    }
}

@MainActor
final class GamificationRuleEvaluator {
    func evaluate(
        triggerType: String,
        entityType: String?,
        entityId: UUID?,
        payload: [String: Any],
        isAnonymous: Bool,
        context: ModelContext
    ) -> [[String: Any]] {
        let descriptor = FetchDescriptor<LocalGamificationRule>(
            predicate: #Predicate { $0.triggerType == triggerType && $0.isActive == true },
            sortBy: [SortDescriptor(\LocalGamificationRule.priority, order: .reverse)]
        )
        let rules = (try? context.fetch(descriptor)) ?? []
        var rewards: [[String: Any]] = []

        for rule in rules {
            guard isInDateWindow(rule), isAudienceMatch(rule.audience, isAnonymous: isAnonymous) else { continue }
            guard conditionsMatch(rule.conditions, payload: payload, entityId: entityId, context: context) else { continue }

            let dedupeKey = makeDedupeKey(rule: rule, triggerType: triggerType, entityType: entityType, entityId: entityId)
            let awardDescriptor = FetchDescriptor<LocalGamificationRuleAward>(
                predicate: #Predicate { $0.dedupeKey == dedupeKey }
            )
            if ((try? context.fetch(awardDescriptor)) ?? []).isEmpty {
                context.insert(LocalGamificationRuleAward(ruleId: rule.id, dedupeKey: dedupeKey))
                rewards.append(rule.reward)
            }
        }

        return rewards
    }

    private func isInDateWindow(_ rule: LocalGamificationRule) -> Bool {
        let now = Date()
        if let startsAt = rule.startsAt, now < startsAt { return false }
        if let endsAt = rule.endsAt, now > endsAt { return false }
        return true
    }

    private func isAudienceMatch(_ audience: String, isAnonymous: Bool) -> Bool {
        switch audience {
        case "all": return true
        case "anonymous": return isAnonymous
        case "registered", "authenticated": return !isAnonymous
        default: return true
        }
    }

    private func conditionsMatch(_ conditions: [String: Any], payload: [String: Any], entityId: UUID?, context: ModelContext) -> Bool {
        if conditions.isEmpty { return true }

        if let expectedPath = conditions["path_id"] as? String,
           payload["path_id"] as? String != expectedPath {
            return false
        }
        if let expectedPOI = conditions["poi_id"] as? String,
           payload["poi_id"] as? String != expectedPOI {
            return false
        }
        if let expectedEvent = conditions["event_id"] as? String,
           payload["event_id"] as? String != expectedEvent {
            return false
        }
        if let minimumPOIs = conditions["poi_count_total_gte"] as? Int {
            let count = ((try? context.fetch(FetchDescriptor<LocalPOIVisit>())) ?? [])
                .reduce(into: Set<UUID>()) { $0.insert($1.poiId) }
                .count
            if count < minimumPOIs { return false }
        }
        if let requiredPercent = conditions["required_completion_percent"] as? Int,
           let currentPercent = payload["completion_percent"] as? Int,
           currentPercent < requiredPercent {
            return false
        }
        return true
    }

    private func makeDedupeKey(rule: LocalGamificationRule, triggerType: String, entityType: String?, entityId: UUID?) -> String {
        if rule.isRepeatable {
            if let cooldown = rule.cooldownSeconds, cooldown > 0 {
                let bucket = Int(Date().timeIntervalSince1970) / cooldown
                return "\(rule.id.uuidString):\(triggerType):\(entityType ?? ""):\(entityId?.uuidString ?? "global"):\(bucket)"
            }
            return "\(rule.id.uuidString):\(triggerType):\(entityType ?? ""):\(entityId?.uuidString ?? "global")"
        }
        return rule.id.uuidString
    }
}

@MainActor
final class XPLevelService {
    func ensureStats(context: ModelContext, deviceId: String) -> LocalUserGamificationStats {
        let descriptor = FetchDescriptor<LocalUserGamificationStats>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let stats = LocalUserGamificationStats(deviceId: deviceId)
        context.insert(stats)
        return stats
    }

    func awardXP(context: ModelContext, deviceId: String, amount: Int, reason: String) -> LocalGamificationLevel? {
        guard amount > 0 else { return nil }
        let stats = ensureStats(context: context, deviceId: deviceId)
        let previousLevel = stats.currentLevel
        stats.xpTotal += amount
        stats.lastActivityAt = Date()
        stats.updatedAt = Date()
        let level = recalculateLevel(context: context, deviceId: deviceId)
        if stats.currentLevel > previousLevel {
            context.insert(LocalGamificationEventLog(
                triggerType: "level_up",
                entityType: "level",
                entityId: level?.id,
                payload: [
                    "level_number": stats.currentLevel,
                    "reason": reason
                ]
            ))
            return level
        }
        return nil
    }

    func recalculateLevel(context: ModelContext, deviceId: String) -> LocalGamificationLevel? {
        let stats = ensureStats(context: context, deviceId: deviceId)
        var descriptor = FetchDescriptor<LocalGamificationLevel>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\LocalGamificationLevel.requiredXP)]
        )
        descriptor.fetchLimit = 100
        let levels = (try? context.fetch(descriptor)) ?? []
        let current = levels.last(where: { stats.xpTotal >= $0.requiredXP })
        if let current {
            stats.currentLevel = current.levelNumber
            stats.currentRank = current.title
        }
        stats.updatedAt = Date()
        return current
    }

    func refreshCounters(context: ModelContext, deviceId: String) {
        let stats = ensureStats(context: context, deviceId: deviceId)
        let visits = ((try? context.fetch(FetchDescriptor<LocalPOIVisit>())) ?? [])
            .reduce(into: Set<UUID>()) { $0.insert($1.poiId) }
        stats.poisVisitedCount = visits.count
        stats.trailsCompletedCount = ((try? context.fetch(FetchDescriptor<LocalTrailProgress>(
            predicate: #Predicate { $0.statusRawValue == "completed" }
        ))) ?? []).count
        stats.badgesUnlockedCount = ((try? context.fetch(FetchDescriptor<LocalUserBadge>(
            predicate: #Predicate { $0.deviceId == deviceId }
        ))) ?? []).count
        stats.speciesUnlockedCount = ((try? context.fetch(FetchDescriptor<LocalUserSpecies>(
            predicate: #Predicate { $0.deviceId == deviceId }
        ))) ?? []).count
        stats.updatedAt = Date()
    }
}

@MainActor
final class BadgeUnlockService {
    func unlockBadge(context: ModelContext, deviceId: String, badgeId: UUID, source: String) -> Bool {
        let descriptor = FetchDescriptor<LocalUserBadge>(
            predicate: #Predicate { $0.deviceId == deviceId && $0.badgeId == badgeId }
        )
        if !(((try? context.fetch(descriptor)) ?? []).isEmpty) {
            return false
        }
        context.insert(LocalUserBadge(deviceId: deviceId, badgeId: badgeId, source: source))
        return true
    }

    func badge(context: ModelContext, badgeId: UUID) -> LocalBadge? {
        let descriptor = FetchDescriptor<LocalBadge>(predicate: #Predicate { $0.id == badgeId })
        return try? context.fetch(descriptor).first
    }

    func badgeName(context: ModelContext, badgeId: UUID) -> String {
        badge(context: context, badgeId: badgeId)?.name ?? "Badge"
    }
}

@MainActor
final class SpeciesCollectionService {
    func unlockSpecies(context: ModelContext, deviceId: String, speciesId: UUID, source: String, sourcePOIId: UUID? = nil, sourcePathId: UUID? = nil) -> Bool {
        let descriptor = FetchDescriptor<LocalUserSpecies>(
            predicate: #Predicate { $0.deviceId == deviceId && $0.speciesId == speciesId }
        )
        if !(((try? context.fetch(descriptor)) ?? []).isEmpty) {
            return false
        }
        context.insert(LocalUserSpecies(
            deviceId: deviceId,
            speciesId: speciesId,
            source: source,
            sourcePOIId: sourcePOIId,
            sourcePathId: sourcePathId
        ))
        return true
    }

    func speciesName(context: ModelContext, speciesId: UUID) -> String {
        let descriptor = FetchDescriptor<LocalSpecies>(predicate: #Predicate { $0.id == speciesId })
        return (try? context.fetch(descriptor).first)?.name ?? "Specie"
    }
}

@MainActor
final class TrailCompletionValidator {
    func validate(trail: Trail, progress: LocalTrailProgress, conditions: [String: Any], context: ModelContext) -> TrailValidationResult {
        let requiredPOIs = trail.sortedSteps.compactMap { $0.poi?.id }
        let visited = progress.visits.reduce(into: [UUID: LocalPOIVisit]()) { partial, visit in
            if partial[visit.poiId] == nil {
                partial[visit.poiId] = visit
            }
        }

        guard !requiredPOIs.isEmpty else {
            return TrailValidationResult(accepted: false, reason: "Il percorso non contiene tappe valide.", completionPercent: 0)
        }

        let visitedRequiredCount = requiredPOIs.filter { visited[$0] != nil }.count
        let percent = Int((Double(visitedRequiredCount) / Double(requiredPOIs.count)) * 100)
        let requiredPercent = conditions["required_completion_percent"] as? Int ?? 100
        guard percent >= requiredPercent else {
            return TrailValidationResult(accepted: false, reason: "Percorso incompleto.", completionPercent: percent)
        }

        if let minimumMinutes = conditions["minimum_duration_minutes"] as? Int,
           let completedAt = progress.completedAt {
            let duration = completedAt.timeIntervalSince(progress.startedAt)
            if duration < Double(minimumMinutes * 60) {
                return TrailValidationResult(accepted: false, reason: "Completamento troppo rapido.", completionPercent: percent)
            }
        }

        if conditions["require_ordered_scans"] as? Bool == true {
            let orderedVisits = progress.visits.sorted { $0.scannedAt < $1.scannedAt }.map(\.poiId)
            let compactRequired = requiredPOIs.filter { orderedVisits.contains($0) }
            if compactRequired != requiredPOIs {
                return TrailValidationResult(accepted: false, reason: "Tappe scansionate fuori ordine.", completionPercent: percent)
            }
        }

        if let minSeconds = conditions["min_seconds_between_scans"] as? Int {
            let sorted = progress.visits.sorted { $0.scannedAt < $1.scannedAt }
            for pair in zip(sorted, sorted.dropFirst()) {
                if pair.1.scannedAt.timeIntervalSince(pair.0.scannedAt) < Double(minSeconds) {
                    return TrailValidationResult(accepted: false, reason: "Scansioni troppo ravvicinate.", completionPercent: percent)
                }
            }
        }

        return TrailValidationResult(accepted: true, reason: nil, completionPercent: percent)
    }
}

@MainActor
final class EventCompletionService {
    func validate(event: Event, validationMethod: String, payload: String?) -> TrailValidationResult {
        let cleanPayload = payload?.trimmingCharacters(in: .whitespacesAndNewlines)

        if validationMethod == "qr", let expected = event.completionQrPayload, !expected.isEmpty {
            guard cleanPayload == expected else {
                return TrailValidationResult(accepted: false, reason: "QR evento non valido.", completionPercent: 0)
            }
        }

        if ["numeric_code", "completion_code"].contains(validationMethod),
           let expected = event.completionNumericCode,
           !expected.isEmpty {
            guard cleanPayload == expected else {
                return TrailValidationResult(accepted: false, reason: "Codice evento non valido.", completionPercent: 0)
            }
        }

        return TrailValidationResult(accepted: true, reason: nil, completionPercent: 100)
    }
}

@MainActor
final class GamificationSyncService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient? = nil) {
        self.networkClient = networkClient ?? SupabaseConfig.shared
    }

    func syncPending(context: ModelContext, userSession: UserSession) async throws {
        try await userSession.ensureGamificationDeviceRegistered()
        try await syncProgress(context: context, userSession: userSession)
        try await syncEventCompletions(context: context, userSession: userSession)
        try await mergeRemoteState(context: context, deviceId: userSession.deviceId)
    }

    private func syncProgress(context: ModelContext, userSession: UserSession) async throws {
        let descriptor = FetchDescriptor<LocalTrailProgress>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let progresses = (try? context.fetch(descriptor)) ?? []

        for progress in progresses {
            let visits = progress.visits.enumerated().map { index, visit in
                [
                    "poi_id": visit.poiId.uuidString,
                    "scanned_at": ISO8601DateFormatter.gamificationString.string(from: visit.scannedAt),
                    "validation_method": visit.sourceRawValue,
                    "source": visit.sourceRawValue,
                    "client_scan_id": visit.id.uuidString,
                    "scan_order": index,
                    "qr_payload_hash": visit.qrPayload?.sha256Fallback ?? ""
                ] as [String: Any]
            }

            let result = try await networkClient.rpc("sync_local_gamification_progress", params: [
                "p_device_id": userSession.deviceId,
                "p_device_secret": userSession.deviceSecret,
                "p_path_id": progress.pathId.uuidString,
                "p_status": progress.statusRawValue,
                "p_started_at": ISO8601DateFormatter.gamificationString.string(from: progress.startedAt),
                "p_completed_at": progress.completedAt.map { ISO8601DateFormatter.gamificationString.string(from: $0) },
                "p_visits": visits,
                "p_events": []
            ])
            mergeStats(result?["stats"] as? [String: Any], context: context, deviceId: userSession.deviceId)
            progress.needsSync = false
            progress.updatedAt = Date()
        }

        try context.save()
    }

    private func syncEventCompletions(context: ModelContext, userSession: UserSession) async throws {
        let descriptor = FetchDescriptor<LocalGamificationEventLog>(
            predicate: #Predicate { $0.triggerType == "event_completed" && $0.syncStatusRawValue == "pending" }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        guard !logs.isEmpty else { return }

        let events = logs.map { log -> [String: Any] in
            let payload = log.payload
            return [
                "event_id": payload["event_id"] as? String ?? log.entityId?.uuidString ?? "",
                "completed_at": payload["completed_at"] as? String ?? ISO8601DateFormatter.gamificationString.string(from: log.occurredAt),
                "validation_method": payload["validation_method"] as? String ?? "manager_check_in",
                "validation_payload": payload["validation_payload"] as? String ?? ""
            ]
        }

        let result = try await networkClient.rpc("sync_local_gamification_progress", params: [
            "p_device_id": userSession.deviceId,
            "p_device_secret": userSession.deviceSecret,
            "p_path_id": nil,
            "p_status": nil,
            "p_started_at": nil,
            "p_completed_at": nil,
            "p_visits": [],
            "p_events": events
        ])
        mergeStats(result?["stats"] as? [String: Any], context: context, deviceId: userSession.deviceId)
        for log in logs {
            log.syncStatus = .synced
            log.syncedAt = Date()
        }
        try context.save()
    }

    private func mergeRemoteState(context: ModelContext, deviceId: String) async throws {
        if let remoteStats = try await networkClient.fetch(from: "gamification_user_stats", query: "select=*").first {
            mergeStats(remoteStats, context: context, deviceId: deviceId)
        }

        let remoteUserSpecies = try await networkClient.fetch(from: "user_species", query: "select=*")
        for data in remoteUserSpecies {
            guard let speciesId = UUID.fromGamificationValue(data["species_id"]) else { continue }
            let descriptor = FetchDescriptor<LocalUserSpecies>(
                predicate: #Predicate { $0.deviceId == deviceId && $0.speciesId == speciesId }
            )
            let existing = try? context.fetch(descriptor).first
            let local = existing ?? LocalUserSpecies(deviceId: deviceId, speciesId: speciesId, source: data["unlock_source"] as? String)
            local.syncedAt = LocalGamificationDateParser.date(from: data["synced_at"]) ?? Date()
            local.syncStatus = .synced
            if existing == nil { context.insert(local) }
        }

        let remoteUserBadges = try await networkClient.fetch(from: "user_badges", query: "select=*")
        for data in remoteUserBadges {
            guard let badgeId = UUID.fromGamificationValue(data["badge_id"]) else { continue }
            let descriptor = FetchDescriptor<LocalUserBadge>(
                predicate: #Predicate { $0.deviceId == deviceId && $0.badgeId == badgeId }
            )
            let existing = try? context.fetch(descriptor).first
            let local = existing ?? LocalUserBadge(deviceId: deviceId, badgeId: badgeId, source: "remote")
            local.syncedAt = Date()
            local.syncStatus = .synced
            if existing == nil { context.insert(local) }
        }

        try context.save()
    }

    private func mergeStats(_ remoteStats: [String: Any]?, context: ModelContext, deviceId: String) {
        guard let remoteStats else { return }
        let descriptor = FetchDescriptor<LocalUserGamificationStats>(
            predicate: #Predicate { $0.deviceId == deviceId }
        )
        let existing = try? context.fetch(descriptor).first
        let stats = existing ?? LocalUserGamificationStats(deviceId: deviceId)
        stats.updateFromRemote(remoteStats)
        if stats.deviceId.isEmpty {
            stats.deviceId = deviceId
        }
        if existing == nil {
            context.insert(stats)
        }
    }
}

extension Notification.Name {
    static let wwfUserDidRegister = Notification.Name("wwfUserDidRegister")
}

extension ISO8601DateFormatter {
    static let gamificationString: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension UUID {
    static func fromGamificationValue(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }
}

private extension String {
    var sha256Fallback: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
