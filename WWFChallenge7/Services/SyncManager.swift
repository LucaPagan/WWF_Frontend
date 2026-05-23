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

        try modelContext.save()
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

        try pruneStaleRecords(of: LocalTranslation.self, remoteIds: remoteIds)
        return count
    }


    // MARK: - Pull POIs

    private func pullPOIs() async throws -> Int {
        let remotePOIs = try await networkClient.fetch(from: "pois", query: "select=*")
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remotePOIs {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let newPOI = createPOIFromRemote(data) {
                modelContext.insert(newPOI)
            }
            count += 1
        }

        // Prune local POIs that no longer exist on server
        try pruneStaleRecords(of: POI.self, remoteIds: remoteIds)

        return count
    }

    // MARK: - Pull Paths

    private func pullPaths() async throws -> Int {
        let remotePaths = try await networkClient.fetch(from: "paths", query: "select=*")
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remotePaths {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let newTrail = createTrailFromRemote(data) {
                modelContext.insert(newTrail)
            }
            count += 1
        }

        // Prune local Trails that no longer exist on server
        try pruneStaleRecords(of: Trail.self, remoteIds: remoteIds)

        return count
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

            // Find existing step
            let stepDescriptor = FetchDescriptor<TrailStep>(predicate: #Predicate { $0.id == remoteId })
            if let existingStep = try modelContext.fetch(stepDescriptor).first {
                // Update mutable fields instead of skipping
                existingStep.stepOrder = data["step_order"] as? Int ?? existingStep.stepOrder
                existingStep.directionHint = data["direction_hint"] as? String ?? existingStep.directionHint
                existingStep.distanceMeters = data["distance_meters"] as? Int ?? existingStep.distanceMeters
                existingStep.estimatedMinutes = data["estimated_minutes"] as? Int ?? existingStep.estimatedMinutes
                existingStep.pathGeometry = data["path_geometry"] as? String
                count += 1
                continue
            }

            // Find parent trail and POI
            let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })

            guard let trail = try modelContext.fetch(trailDescriptor).first,
                  let poi = try modelContext.fetch(poiDescriptor).first else { continue }

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

        // Prune orphaned steps
        try pruneStaleRecords(of: TrailStep.self, remoteIds: remoteIds)

        return count
    }

    // MARK: - Pull Contents

    private func pullContents() async throws -> Int {
        let remoteContents = try await networkClient.fetch(
            from: "contents",
            query: "select=*&order=sort_order.asc"
        )
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remoteContents {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            guard let poiIdStr = data["poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) else { continue }

            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<Content>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else {
                let typeStr = data["type"] as? String ?? "text"
                let tierStr = data["tier"] as? String ?? "light"
                let content = Content(
                    poiId: poiId,
                    type: ContentType(rawValue: typeStr) ?? .text,
                    tier: ContentTier(rawValue: tierStr) ?? .light,
                    fileURL: data["file_url"] as? String,
                    sortOrder: data["sort_order"] as? Int ?? 0,
                    altText: data["alt_text"] as? String,
                    durationSeconds: data["duration_seconds"] as? Int,
                    languageCode: data["language_code"] as? String ?? "it",
                    transcriptText: data["transcript_text"] as? String,
                    hasEasyRead: data["has_easy_read"] as? Bool ?? false,
                    subtitleURL: data["subtitle_url"] as? String,
                    fixedID: remoteId
                )
                // Handle JSONB data field
                if let jsonObj = data["data"], !(jsonObj is NSNull) {
                    if JSONSerialization.isValidJSONObject(jsonObj) {
                        content.data = try? JSONSerialization.data(withJSONObject: jsonObj)
                    }
                }
                modelContext.insert(content)
            }
            count += 1
        }

        try pruneStaleRecords(of: Content.self, remoteIds: remoteIds)
        return count
    }

    // MARK: - Pull Events

    private func pullEvents() async throws -> Int {
        let remoteEvents = try await networkClient.fetch(from: "events", query: "select=*")
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remoteEvents {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            remoteIds.insert(remoteId)
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else if let newEvent = createEventFromRemote(data) {
                modelContext.insert(newEvent)
            }
            count += 1
        }

        // Prune local Events that no longer exist on server
        try pruneStaleRecords(of: Event.self, remoteIds: remoteIds)

        return count
    }

    // MARK: - Pull DownloadPackages

    private func pullDownloadPackages() async throws -> Int {
        let remotePackages = try await networkClient.fetch(
            from: "download_packages",
            query: "select=*"
        )
        var remoteIds = Set<UUID>()
        var count = 0

        for data in remotePackages {
            guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
            guard let pathIdStr = data["path_id"] as? String, let pathId = UUID(uuidString: pathIdStr) else { continue }

            remoteIds.insert(remoteId)

            let descriptor = FetchDescriptor<DownloadPackage>(predicate: #Predicate { $0.id == remoteId })

            if let existing = try modelContext.fetch(descriptor).first {
                existing.updateFromRemote(data)
            } else {
                let tierStr = data["tier"] as? String ?? "light"
                let pkg = DownloadPackage(
                    pathId: pathId,
                    tier: ContentTier(rawValue: tierStr) ?? .light,
                    sizeBytes: (data["size_bytes"] as? Int64) ?? Int64(data["size_bytes"] as? Int ?? 0),
                    includesVideo: data["includes_video"] as? Bool ?? false,
                    includes3D: data["includes_3d"] as? Bool ?? false,
                    bundleURL: data["bundle_url"] as? String,
                    isReady: data["is_ready"] as? Bool ?? false,
                    fixedID: remoteId
                )
                modelContext.insert(pkg)
            }
            count += 1
        }
        return count
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

    // MARK: - Factory Methods

    private func createPOIFromRemote(_ data: [String: Any]) -> POI? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String,
              let desc = data["poi_description"] as? String,
              let x = data["x"] as? Double,
              let y = data["y"] as? Double else { return nil }

        let typeStr = data["type"] as? String ?? "landmark"
        let poiType = POIType.fromSupabase(typeStr) ?? .landmark

        let poi = POI(
            name: name,
            description: desc,
            x: x,
            y: y,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            type: poiType,
            photoURL: data["photo_url"] as? String,
            isStartPoint: data["is_start_point"] as? Bool ?? false,
            isActive: data["is_active"] as? Bool ?? true,
            iconName: data["icon_name"] as? String,
            numericCode: data["numeric_code"] as? String,
            descriptionKids: data["description_kids"] as? String,
            descriptionEasyRead: data["description_easy_read"] as? String,
            fixedID: id
        )
        poi.qrPayload = data["qr_payload"] as? String ?? "ASTRONI_POI_\(id.uuidString)"
        poi.needsSync = false
        return poi
    }

    private func createTrailFromRemote(_ data: [String: Any]) -> Trail? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String else { return nil }

        let diffStr = data["difficulty"] as? String
        let difficulty = diffStr.flatMap { TrailDifficulty.fromSupabase($0) }

        let startPOIIdStr = data["start_poi_id"] as? String
        let startPOIId = startPOIIdStr.flatMap { UUID(uuidString: $0) }

        let trail = Trail(
            name: name,
            description: data["description"] as? String ?? "",
            isActive: data["is_active"] as? Bool ?? false,
            difficulty: difficulty,
            estimatedMinutes: data["estimated_minutes"] as? Int,
            coverImageURL: data["cover_image_url"] as? String,
            startPOIId: startPOIId,
            targetAge: data["target_age"] as? String,
            descriptionKids: data["description_kids"] as? String,
            descriptionEasyRead: data["description_easy_read"] as? String,
            fixedID: id
        )
        trail.needsSync = false
        return trail
    }

    private func createEventFromRemote(_ data: [String: Any]) -> Event? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String else { return nil }

        let catStr = data["category"] as? String ?? "other"
        let category = EventCategory.fromSupabase(catStr) ?? .other
        let audienceStr = data["target_audience"] as? String ?? "all"
        let audience = EventAudience.fromSupabase(audienceStr) ?? .all

        // Parse date and times
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss"

        let dateStr = data["date"] as? String ?? ""
        let eventDate = dateFmt.date(from: dateStr) ?? Date()

        let startStr = data["time_start"] as? String ?? "09:00:00"
        let endStr = data["time_end"] as? String ?? "17:00:00"
        let startTime = timeFmt.date(from: startStr) ?? Date()
        let endTime = timeFmt.date(from: endStr) ?? Date()

        let event = Event(
            name: name,
            description: data["description"] as? String ?? "",
            category: category,
            date: eventDate,
            startTime: startTime,
            endTime: endTime,
            maxParticipants: data["max_participants"] as? Int,
            organizerName: data["organizer_name"] as? String,
            contactInfo: data["contact_info"] as? String,
            requirements: data["requirements"] as? String,
            targetAudience: audience,
            price: data["price"] as? Double ?? 0,
            imageURL: data["image_url"] as? String,
            fixedID: id
        )
        event.isActive = data["is_active"] as? Bool ?? false
        event.needsSync = false

        // Link trail and POI if present
        if let pathIdStr = data["path_id"] as? String, let pathId = UUID(uuidString: pathIdStr) {
            let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
            event.trail = try? modelContext.fetch(trailDescriptor).first
        }
        if let poiIdStr = data["event_poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) {
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })
            event.eventPOI = try? modelContext.fetch(poiDescriptor).first
        }

        return event
    }
}
