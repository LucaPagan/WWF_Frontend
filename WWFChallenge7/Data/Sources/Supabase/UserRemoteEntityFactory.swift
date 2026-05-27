//
//  UserRemoteEntityFactory.swift
//  WWFChallenge7
//

import Foundation
import SwiftData

struct UserRemoteEntityFactory {
    nonisolated(unsafe) let modelContext: ModelContext

    nonisolated func makePOI(from data: [String: Any]) -> POI? {
        guard let id = UUID.fromSupabase(data["id"]),
              let name = data["name"] as? String,
              let description = data["poi_description"] as? String,
              let x = data["x"] as? Double,
              let y = data["y"] as? Double else {
            return nil
        }

        let typeRawValue = data["type"] as? String ?? "landmark"
        let poi = POI(
            name: name,
            description: description,
            x: x,
            y: y,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            type: POIType.fromSupabase(typeRawValue) ?? .landmark,
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

    nonisolated func makeTrail(from data: [String: Any]) -> Trail? {
        guard let id = UUID.fromSupabase(data["id"]),
              let name = data["name"] as? String else {
            return nil
        }

        let difficulty = (data["difficulty"] as? String).flatMap(TrailDifficulty.fromSupabase)
        let trail = Trail(
            name: name,
            description: data["description"] as? String ?? "",
            isActive: data["is_active"] as? Bool ?? false,
            difficulty: difficulty,
            estimatedMinutes: data["estimated_minutes"] as? Int,
            coverImageURL: data["cover_image_url"] as? String,
            startPOIId: UUID.fromSupabase(data["start_poi_id"]),
            targetAge: data["target_age"] as? String,
            descriptionKids: data["description_kids"] as? String,
            descriptionEasyRead: data["description_easy_read"] as? String,
            fixedID: id
        )
        trail.needsSync = false
        return trail
    }

    nonisolated func makeContent(from data: [String: Any]) -> Content? {
        guard let id = UUID.fromSupabase(data["id"]),
              let poiId = UUID.fromSupabase(data["poi_id"]) else {
            return nil
        }

        let content = Content(
            poiId: poiId,
            type: ContentType(rawValue: data["type"] as? String ?? "text") ?? .text,
            tier: ContentTier(rawValue: data["tier"] as? String ?? "light") ?? .light,
            fileURL: data["file_url"] as? String,
            sortOrder: data["sort_order"] as? Int ?? 0,
            altText: data["alt_text"] as? String,
            durationSeconds: data["duration_seconds"] as? Int,
            languageCode: data["language_code"] as? String ?? "it",
            transcriptText: data["transcript_text"] as? String,
            hasEasyRead: data["has_easy_read"] as? Bool ?? false,
            subtitleURL: data["subtitle_url"] as? String,
            fixedID: id
        )
        content.data = Self.jsonData(from: data["data"])
        return content
    }

    nonisolated func makeEvent(from data: [String: Any]) -> Event? {
        guard let id = UUID.fromSupabase(data["id"]),
              let name = data["name"] as? String else {
            return nil
        }

        let event = Event(
            name: name,
            description: data["description"] as? String ?? "",
            category: EventCategory.fromSupabase(data["category"] as? String ?? "other") ?? .other,
            date: Self.dateOnly(from: data["date"] as? String) ?? Date(),
            startTime: Self.timeOnly(from: data["time_start"] as? String) ?? Date(),
            endTime: Self.timeOnly(from: data["time_end"] as? String) ?? Date(),
            maxParticipants: data["max_participants"] as? Int,
            organizerName: data["organizer_name"] as? String,
            contactInfo: data["contact_info"] as? String,
            requirements: data["requirements"] as? String,
            targetAudience: EventAudience.fromSupabase(data["target_audience"] as? String ?? "all") ?? .all,
            price: data["price"] as? Double ?? 0,
            imageURL: data["image_url"] as? String,
            fixedID: id
        )
        event.isActive = data["is_active"] as? Bool ?? false
        event.needsSync = false
        event.trail = fetchTrail(id: UUID.fromSupabase(data["path_id"]))
        event.eventPOI = fetchPOI(id: UUID.fromSupabase(data["event_poi_id"]))
        return event
    }

    nonisolated func makeDownloadPackage(from data: [String: Any]) -> DownloadPackage? {
        guard let id = UUID.fromSupabase(data["id"]),
              let pathId = UUID.fromSupabase(data["path_id"]) else {
            return nil
        }

        let package = DownloadPackage(
            pathId: pathId,
            tier: ContentTier(rawValue: data["tier"] as? String ?? "light") ?? .light,
            sizeBytes: Self.int64Value(data["size_bytes"]),
            includesVideo: data["includes_video"] as? Bool ?? false,
            includes3D: data["includes_3d"] as? Bool ?? false,
            bundleURL: data["bundle_url"] as? String,
            isReady: data["is_ready"] as? Bool ?? false,
            fixedID: id
        )
        package.updateFromRemote(data)
        return package
    }

    private nonisolated func fetchTrail(id: UUID?) -> Trail? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private nonisolated func fetchPOI(id: UUID?) -> POI? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private nonisolated static func dateOnly(from value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private nonisolated static func timeOnly(from value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.date(from: value)
    }

    private nonisolated static func jsonData(from value: Any?) -> Data? {
        guard let value, !(value is NSNull), JSONSerialization.isValidJSONObject(value) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: value)
    }

    private nonisolated static func int64Value(_ value: Any?) -> Int64 {
        if let int64 = value as? Int64 { return int64 }
        if let int = value as? Int { return Int64(int) }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String, let parsed = Int64(string) { return parsed }
        return 0
    }
}

private extension UUID {
    nonisolated static func fromSupabase(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }
}
