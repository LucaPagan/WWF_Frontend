//
//  SyncManager.swift
//  WWFChallenge7
//
//  User-module SyncManager — PULL-ONLY.
//  Unlike the Manager's bidirectional sync, this only downloads
//  public data (POIs, Paths, PathSteps, Events) from Supabase.
//  RLS allows anon-key SELECT on is_active=true records.
//

import Foundation
import SwiftData
import Combine

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing(entity: String)
    case success(count: Int)
    case error(message: String)
}

// MARK: - SyncManager (MainActor coordinator)

@MainActor
final class SyncManager: ObservableObject {

    @Published var syncState: SyncState = .idle
    @Published var lastSyncDate: Date?

    private var modelContainer: ModelContainer?
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient? = nil) {
        self.networkClient = networkClient ?? SupabaseConfig.shared
    }

    func configure(with context: ModelContext) {
        self.modelContainer = context.container
    }

    /// Pulls all public data from Supabase into SwiftData.
    /// Called on app launch and on manual refresh.
    func pullLatestData() async {
        guard let container = modelContainer else { return }

        do {
            syncState = .syncing(entity: "Download dati")

            let worker = UserSyncWorker(
                modelContainer: container,
                networkClient: networkClient
            )
            let count = try await worker.performFullPull()

            syncState = .success(count: count)
            lastSyncDate = Date()
        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }

    func pushPendingProgress(deviceId: String) async {
        guard let container = modelContainer else { return }
        guard await SupabaseConfig.shared.currentSession() != nil else { return }

        do {
            let worker = UserSyncWorker(
                modelContainer: container,
                networkClient: networkClient
            )
            try await worker.pushPendingProgress(deviceId: deviceId)
        } catch {
            syncState = .error(message: error.localizedDescription)
        }
    }
}

// MARK: - UserSyncWorker (Background ModelActor)

actor UserSyncWorker: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    let networkClient: NetworkClient

    init(modelContainer: ModelContainer, networkClient: NetworkClient) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: ModelContext(modelContainer)
        )
        self.networkClient = networkClient
    }

    /// Pulls POIs → Paths → PathSteps → Events → DownloadPackages
    /// Also prunes local records that no longer exist on the server.
    func performFullPull() async throws -> Int {
        var count = 0

        // 1. POIs (RLS: is_active = true)
        count += try await pullPOIs()

        // 2. Paths (RLS: is_active = true)
        count += try await pullPaths()

        // 3. PathSteps (RLS: path.is_active = true)
        count += try await pullPathSteps()

        // 4. Events (RLS: is_active = true)
        count += try await pullEvents()

        // 5. DownloadPackages (RLS: is_ready = true)
        count += try await pullDownloadPackages()

        // 6. Contents
        count += try await pullContents()

        // 7. Translations
        count += try await pullTranslations()

        // 8. Gamification definitions
        count += try await pullGamificationLevels()
        count += try await pullGamificationRules()
        count += try await pullBadges()
        count += try await pullSpecies()

        try modelContext.save()
        return count
    }

    // MARK: - Pull Gamification

    private func pullGamificationLevels() async throws -> Int {
        let remoteLevels = try await networkClient.fetch(
            from: "gamification_levels",
            query: "select=*&order=required_xp.asc"
        )
        var count = 0

        for data in remoteLevels {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<LocalGamificationLevel>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else {
                let level = LocalGamificationLevel(
                    id: remoteId,
                    levelNumber: data["level_number"] as? Int ?? 1,
                    title: data["title"] as? String ?? "Visitatore",
                    description: data["description"] as? String,
                    requiredXP: data["required_xp"] as? Int ?? 0,
                    iconName: data["icon_name"] as? String,
                    imageURL: data["image_url"] as? String,
                    isActive: data["is_active"] as? Bool ?? true,
                    createdAt: LocalGamificationDateParser.date(from: data["created_at"]) ?? Date(),
                    updatedAt: LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
                )
                modelContext.insert(level)
            }
            count += 1
        }

        return count
    }

    private func pullGamificationRules() async throws -> Int {
        let remoteRules = try await networkClient.fetch(
            from: "gamification_rules",
            query: "select=*&order=priority.desc"
        )
        var count = 0

        for data in remoteRules {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<LocalGamificationRule>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else {
                let rule = LocalGamificationRule(
                    id: remoteId,
                    title: data["title"] as? String ?? "Regola",
                    description: data["description"] as? String,
                    triggerType: data["trigger_type"] as? String ?? "",
                    conditions: data["conditions_json"] as? [String: Any] ?? [:],
                    reward: data["reward_json"] as? [String: Any] ?? [:],
                    audience: data["audience"] as? String ?? "all",
                    isHidden: data["is_hidden"] as? Bool ?? false,
                    isRepeatable: data["is_repeatable"] as? Bool ?? false,
                    cooldownSeconds: data["cooldown_seconds"] as? Int,
                    startsAt: LocalGamificationDateParser.date(from: data["starts_at"]),
                    endsAt: LocalGamificationDateParser.date(from: data["ends_at"]),
                    priority: data["priority"] as? Int ?? 0,
                    isActive: data["is_active"] as? Bool ?? true,
                    createdAt: LocalGamificationDateParser.date(from: data["created_at"]) ?? Date(),
                    updatedAt: LocalGamificationDateParser.date(from: data["updated_at"]) ?? Date()
                )
                modelContext.insert(rule)
            }
            count += 1
        }

        return count
    }

    private func pullBadges() async throws -> Int {
        let remoteBadges = try await networkClient.fetch(
            from: "badges",
            query: "select=*&order=sort_order.asc"
        )
        var count = 0

        for data in remoteBadges {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<LocalBadge>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else {
                let badge = LocalBadge(
                    id: remoteId,
                    name: data["name"] as? String ?? "Badge",
                    description: data["description"] as? String
                )
                badge.updateFromRemote(data)
                modelContext.insert(badge)
            }
            count += 1
        }

        return count
    }

    private func pullSpecies() async throws -> Int {
        let remoteSpecies = try await networkClient.fetch(
            from: "species",
            query: "select=*&order=name.asc"
        )
        var count = 0

        for data in remoteSpecies {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            let descriptor = FetchDescriptor<LocalSpecies>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else {
                let species = LocalSpecies(
                    id: remoteId,
                    name: data["name"] as? String ?? "Specie",
                    description: data["description"] as? String ?? "",
                    category: data["category"] as? String ?? "fauna"
                )
                species.updateFromRemote(data)
                modelContext.insert(species)
            }
            count += 1
        }

        return count
    }

    // MARK: - Pull Translations

    private func pullTranslations() async throws -> Int {
        let remoteTranslations = try await networkClient.fetch(from: "translations", query: "select=*")
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remoteTranslations {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            guard let tableName = data["table_name"] as? String,
                  let recordIdStr = data["record_id"] as? String, let recordId = UUID(uuidString: recordIdStr),
                  let fieldName = data["field_name"] as? String,
                  let langCode = data["language_code"] as? String,
                  let rawTranslatedText = data["translated_text"] as? String else { continue }
            
            let translatedText = rawTranslatedText

            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<LocalTranslation>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.tableName = tableName
                existing.recordId = recordId
                existing.fieldName = fieldName
                existing.languageCode = langCode
                existing.translatedText = translatedText
            } else {
                let trans = LocalTranslation(
                    tableName: tableName,
                    recordId: recordId,
                    fieldName: fieldName,
                    languageCode: langCode,
                    translatedText: translatedText,
                    fixedID: remoteId
                )
                modelContext.insert(trans)
            }
            count += 1
        }

        return count
    }


    // MARK: - Pull POIs

    private func pullPOIs() async throws -> Int {
        let remotePOIs = try await networkClient.fetch(from: "pois", query: "select=*")
        let remoteFactory = UserRemoteEntityFactory(modelContext: modelContext)
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remotePOIs {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let newPOI = remoteFactory.makePOI(from: data) {
                modelContext.insert(newPOI)
            }
            count += 1
        }

        return count
    }

    // MARK: - Pull Paths

    private func pullPaths() async throws -> Int {
        let remotePaths = try await networkClient.fetch(from: "paths", query: "select=*")
        let remoteFactory = UserRemoteEntityFactory(modelContext: modelContext)
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remotePaths {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let newTrail = remoteFactory.makeTrail(from: data) {
                modelContext.insert(newTrail)
            }
            count += 1
        }

        try reconcileLocalTrails(withRemoteIds: remoteIds)
        return count
    }

    private func reconcileLocalTrails(withRemoteIds remoteIds: Set<UUID>) throws {
        guard !remoteIds.isEmpty else { return }

        let localTrails = try modelContext.fetch(FetchDescriptor<Trail>())
        for trail in localTrails where !remoteIds.contains(trail.id) {
            trail.isActive = false
            trail.needsSync = false
        }
    }

    // MARK: - Pull PathSteps

    private func pullPathSteps() async throws -> Int {
        let remoteSteps = try await networkClient.fetch(
            from: "path_steps",
            query: "select=*&order=step_order.asc"
        )
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remoteSteps {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            guard let pathIdStr = data["path_id"] as? String, let pathId = UUID(uuidString: pathIdStr) else { continue }
            guard let poiIdStr = data["poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) else { continue }

            remoteIds.insert(remoteId)

            let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })
            guard let trail = try modelContext.fetch(trailDescriptor).first,
                  let poi = try modelContext.fetch(poiDescriptor).first else { continue }

            let stepDescriptor = FetchDescriptor<TrailStep>(predicate: #Predicate { $0.id == remoteId })
            if let existingStep = try modelContext.fetch(stepDescriptor).first {
                existingStep.stepOrder = data["step_order"] as? Int ?? existingStep.stepOrder
                existingStep.directionHint = data["direction_hint"] as? String ?? existingStep.directionHint
                existingStep.distanceMeters = data["distance_meters"] as? Int ?? existingStep.distanceMeters
                existingStep.estimatedMinutes = data["estimated_minutes"] as? Int ?? existingStep.estimatedMinutes
                existingStep.pathGeometry = data["path_geometry"] as? String
                existingStep.poi = poi
                if !trail.steps.contains(where: { $0.id == existingStep.id }) {
                    trail.steps.append(existingStep)
                }
                count += 1
                continue
            }

            let step = TrailStep(
                stepOrder: data["step_order"] as? Int ?? 0,
                directionHint: data["direction_hint"] as? String ?? "",
                distanceMeters: data["distance_meters"] as? Int ?? 0,
                estimatedMinutes: data["estimated_minutes"] as? Int ?? 0,
                pathGeometry: data["path_geometry"] as? String,
                poi: poi,
                fixedID: remoteId
            )

            trail.steps.append(step)
            count += 1
        }

        try pruneStaleRecords(of: TrailStep.self, remoteIds: remoteIds)
        return count
    }

    // MARK: - Pull Contents

    private func pullContents() async throws -> Int {
        let remoteContents = try await networkClient.fetch(
            from: "contents",
            query: "select=*&order=sort_order.asc"
        )
        let remoteFactory = UserRemoteEntityFactory(modelContext: modelContext)
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remoteContents {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }

            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<Content>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let content = remoteFactory.makeContent(from: data) {
                modelContext.insert(content)
            }
            count += 1
        }

        return count
    }

    // MARK: - Pull Events

    private func pullEvents() async throws -> Int {
        let remoteEvents = try await networkClient.fetch(from: "events", query: "select=*")
        let remoteFactory = UserRemoteEntityFactory(modelContext: modelContext)
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remoteEvents {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
                try updateEventRelationships(existing, from: data)
            } else if let newEvent = remoteFactory.makeEvent(from: data) {
                modelContext.insert(newEvent)
            }
            count += 1
        }

        // Prune local Events that no longer exist on server
        try pruneStaleRecords(of: Event.self, remoteIds: remoteIds)

        return count
    }

    private func updateEventRelationships(_ event: Event, from data: [String: Any]) throws {
        event.trail = try fetchTrail(id: Self.uuidValue(data["path_id"]))
        event.eventPOI = try fetchPOI(id: Self.uuidValue(data["event_poi_id"]))
    }

    private func fetchTrail(id: UUID?) throws -> Trail? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private func fetchPOI(id: UUID?) throws -> POI? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private nonisolated static func uuidValue(_ value: Any?) -> UUID? {
        guard let value, !(value is NSNull) else { return nil }
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }

    // MARK: - Pull DownloadPackages

    private func pullDownloadPackages() async throws -> Int {
        let remotePackages = try await networkClient.fetch(
            from: "download_packages",
            query: "select=*"
        )
        let remoteFactory = UserRemoteEntityFactory(modelContext: modelContext)
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remotePackages {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }

            remoteIds.insert(remoteId)

            let descriptor = FetchDescriptor<DownloadPackage>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let package = remoteFactory.makeDownloadPackage(from: data) {
                modelContext.insert(package)
            }
            count += 1
        }
        return count
    }

    func pushPendingProgress(deviceId: String) async throws {
        let descriptor = FetchDescriptor<LocalTrailProgress>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let progresses = try modelContext.fetch(descriptor)

        for progress in progresses {
            let visits = progress.visits.map { visit in
                [
                    "poi_id": visit.poiId.uuidString,
                    "scanned_at": ISO8601DateFormatter().string(from: visit.scannedAt)
                ]
            }
            _ = try await networkClient.rpc("sync_user_progress", params: [
                "p_path_id": progress.pathId.uuidString,
                "p_status": progress.statusRawValue,
                "p_started_at": ISO8601DateFormatter().string(from: progress.startedAt),
                "p_completed_at": progress.completedAt.map { ISO8601DateFormatter().string(from: $0) },
                "p_device_id": deviceId,
                "p_visits": visits
            ])
            progress.needsSync = false
            progress.updatedAt = Date()
        }

        try modelContext.save()
    }

    // MARK: - Stale Record Pruning

    /// Removes local records whose IDs are not present in the remote dataset.
    /// This ensures deactivated or deleted content is cleaned up locally.
    private func pruneStaleRecords<T: PersistentModel>(of type: T.Type, remoteIds: Set<UUID>) throws where T: Identifiable, T.ID == UUID {
        let allLocal = try modelContext.fetch(FetchDescriptor<T>())
        for local in allLocal {
            if !remoteIds.contains(local.id) {
                modelContext.delete(local)
            }
        }
    }

}
