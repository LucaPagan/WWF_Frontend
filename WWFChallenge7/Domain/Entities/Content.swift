//
//  Content.swift
//  WWFChallenge7
//
//  SwiftData entity — mirrors Supabase table: public.contents
//  Represents multimedia content attached to a POI, tiered by download level.
//

import Foundation
import SwiftData

@Model
final class Content {
    var id: UUID
    var poiId: UUID
    var typeRawValue: String
    var tierRawValue: String
    var data: Data?           // DB: jsonb — stored as serialised JSON
    var fileURL: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    @Transient var contentType: ContentType {
        get { ContentType(rawValue: typeRawValue) ?? .text }
        set { typeRawValue = newValue.rawValue }
    }

    @Transient var tier: ContentTier {
        get { ContentTier(rawValue: tierRawValue) ?? .light }
        set { tierRawValue = newValue.rawValue }
    }

    init(
        poiId: UUID,
        type: ContentType = .text,
        tier: ContentTier = .light,
        data: Data? = nil,
        fileURL: String? = nil,
        sortOrder: Int = 0,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.poiId = poiId
        self.typeRawValue = type.rawValue
        self.tierRawValue = tier.rawValue
        self.data = data
        self.fileURL = fileURL
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateFromRemote(_ remoteData: [String: Any]) {
        if let t = remoteData["type"] as? String { typeRawValue = t }
        if let ti = remoteData["tier"] as? String { tierRawValue = ti }
        fileURL = remoteData["file_url"] as? String
        if let so = remoteData["sort_order"] as? Int { sortOrder = so }
        // jsonb data field is stored as serialised Data if present
        if let jsonObj = remoteData["data"], !(jsonObj is NSNull) {
            if JSONSerialization.isValidJSONObject(jsonObj) {
                data = try? JSONSerialization.data(withJSONObject: jsonObj)
            } else {
                data = try? JSONSerialization.data(withJSONObject: jsonObj, options: .fragmentsAllowed)
            }
        } else {
            data = nil
        }
    }
}

// MARK: - Content Enums (mirror Supabase ENUMs)

enum ContentType: String, Codable, CaseIterable {
    case text     = "text"
    case image    = "image"
    case video    = "video"
    case model3d  = "model_3d"
    case audio    = "audio"

    var displayName: String {
        switch self {
        case .text:    return "Testo"
        case .image:   return "Immagine"
        case .video:   return "Video"
        case .model3d: return "Modello 3D"
        case .audio:   return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .text:    return "doc.text.fill"
        case .image:   return "photo.fill"
        case .video:   return "play.rectangle.fill"
        case .model3d: return "cube.fill"
        case .audio:   return "waveform.circle.fill"
        }
    }
}

enum ContentTier: String, Codable, CaseIterable {
    case light    = "light"
    case standard = "standard"
    case full     = "full"

    var displayName: String {
        switch self {
        case .light:    return "Essenziale"
        case .standard: return "Standard"
        case .full:     return "Completo"
        }
    }

    /// Estimated size factor for UI display
    var sizeLabel: String {
        switch self {
        case .light:    return "~5 MB"
        case .standard: return "~25 MB"
        case .full:     return "~100 MB"
        }
    }
}

// MARK: - Offline Extensions

extension Content {
    var localFileName: String {
        var ext = ""
        if let urlStr = fileURL, let url = URL(string: urlStr) {
            ext = url.pathExtension
        }
        if ext.isEmpty {
            switch contentType {
            case .image: ext = "jpg"
            case .video: ext = "mp4"
            case .audio: ext = "mp3"
            case .model3d: ext = "usdz"
            case .text: ext = "json"
            }
        }
        return "media/\(id.uuidString).\(ext)"
    }
    
    var localFileURL: URL? {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDir = documentsDir.appendingPathComponent("OfflineContent", isDirectory: true)
        let fileURL = baseDir.appendingPathComponent(localFileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    func text(forLanguage lang: String) -> String? {
        guard let data = data else { return nil }
        // Try parsing as key-value dictionary [String: String]
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return dict[lang] ?? dict["it"] ?? dict["en"] ?? dict.values.first
        }
        // Try parsing as key-value dictionary [String: Any]
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let val = dict[lang] as? String { return val }
            if let val = dict["text"] as? String { return val }
            if let val = dict["it"] as? String { return val }
            if let val = dict["en"] as? String { return val }
            if let textDict = dict["text"] as? [String: String] {
                return textDict[lang] ?? textDict["it"] ?? textDict["en"] ?? textDict.values.first
            }
        }
        // Fallback: try parsing as a single string
        if let singleString = try? JSONSerialization.jsonObject(with: data) as? String {
            return singleString
        }
        if let rawString = String(data: data, encoding: .utf8) {
            return rawString
        }
        return nil
    }
}
