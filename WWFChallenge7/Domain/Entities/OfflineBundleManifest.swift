import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var foundationObject: Any {
        switch self {
        case .string(let value): return value
        case .number(let value):
            if value.rounded() == value, value <= Double(Int.max), value >= Double(Int.min) {
                return Int(value)
            }
            return value
        case .bool(let value): return value
        case .object(let value): return value.mapValues { $0.foundationObject }
        case .array(let value): return value.map { $0.foundationObject }
        case .null: return NSNull()
        }
    }
}

struct OfflineBundleManifest: Codable, Equatable {
    let manifestVersion: String
    let manifestSHA256: String
    let generatedAt: Date?
    let requiredAppVersion: String?
    let pathId: UUID
    let tier: ContentTier
    let includedTiers: [ContentTier]
    let path: [String: JSONValue]
    let pathSteps: [[String: JSONValue]]
    let pois: [[String: JSONValue]]
    let globalAlerts: [[String: JSONValue]]
    let contents: [[String: JSONValue]]
    let translations: [[String: JSONValue]]
    let assets: [OfflineBundleAsset]

    enum CodingKeys: String, CodingKey {
        case manifestVersion = "manifest_version"
        case manifestSHA256 = "manifest_sha256"
        case generatedAt = "generated_at"
        case requiredAppVersion = "required_app_version"
        case pathId = "path_id"
        case tier
        case includedTiers = "included_tiers"
        case path
        case pathSteps = "path_steps"
        case pois
        case globalAlerts = "global_alerts"
        case contents
        case translations
        case assets
    }
}

struct OfflineBundleAsset: Codable, Equatable, Identifiable {
    let id: String
    let kind: String
    let contentId: UUID?
    let poiId: UUID?
    let type: String
    let bucket: String
    let storagePath: String
    let localRelativePath: String
    let sizeBytes: Int64
    let sha256: String
    let mimeType: String?
    var signedURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case contentId = "content_id"
        case poiId = "poi_id"
        case type
        case bucket
        case storagePath = "storage_path"
        case localRelativePath = "local_relative_path"
        case sizeBytes = "size_bytes"
        case sha256
        case mimeType = "mime_type"
        case signedURL = "signed_url"
    }
}

struct BundleDownloadState: Codable, Equatable {
    var packageId: UUID
    var manifestSHA256: String
    var completedAssetIds: Set<String>
    var updatedAt: Date
}

struct BundleEnvelope {
    let manifest: OfflineBundleManifest
    let signedAssets: [String: String]
}

extension Dictionary where Key == String, Value == JSONValue {
    var foundationDictionary: [String: Any] {
        mapValues { $0.foundationObject }
    }
}
