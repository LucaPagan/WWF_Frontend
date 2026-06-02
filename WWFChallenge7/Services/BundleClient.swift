import Foundation

enum BundleClientError: LocalizedError {
    case missingManifest
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingManifest: return "Manifest bundle non disponibile."
        case .malformedResponse: return "Risposta bundle non valida."
        }
    }
}

final class BundleClient {
    private let supabase: SupabaseConfig
    private let decoder: JSONDecoder

    init(supabase: SupabaseConfig = .shared) {
        self.supabase = supabase
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: raw) {
                return date
            }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
        }
    }

    func fetchBundle(pathId: UUID, tier: ContentTier) async throws -> BundleEnvelope {
        let response = try await supabase.invokeFunction(
            "get-bundle",
            queryItems: [
                URLQueryItem(name: "path_id", value: pathId.uuidString),
                URLQueryItem(name: "tier", value: tier.rawValue)
            ]
        )
        return try decodeEnvelope(response)
    }

    func refreshSignedAssets(pathId: UUID, tier: ContentTier) async throws -> [String: String] {
        let response = try await supabase.invokeFunction(
            "get-bundle",
            queryItems: [
                URLQueryItem(name: "path_id", value: pathId.uuidString),
                URLQueryItem(name: "tier", value: tier.rawValue),
                URLQueryItem(name: "refresh_assets", value: "true")
            ]
        )
        return try decodeSignedAssets(response)
    }

    private func decodeEnvelope(_ response: [String: Any]) throws -> BundleEnvelope {
        guard let manifestObject = response["manifest"] else {
            throw BundleClientError.missingManifest
        }
        let manifestData = try JSONSerialization.data(withJSONObject: manifestObject)
        let manifest = try decoder.decode(OfflineBundleManifest.self, from: manifestData)
        let bundle = response["bundle"] as? [String: Any]
        return BundleEnvelope(
            manifest: manifest,
            bundleManifestSHA256: bundle?["manifest_sha256"] as? String,
            bundleSizeBytes: Self.int64Value(bundle?["size_bytes"]),
            bundleAssetCount: bundle?["asset_count"] as? Int,
            generatedAt: Self.dateValue(bundle?["generated_at"], decoder: decoder),
            signedAssets: try decodeSignedAssets(response)
        )
    }

    private func decodeSignedAssets(_ response: [String: Any]) throws -> [String: String] {
        guard let assets = response["assets"] as? [[String: Any]] else {
            throw BundleClientError.malformedResponse
        }
        var signed: [String: String] = [:]
        for asset in assets {
            if let id = asset["id"] as? String, let url = asset["signed_url"] as? String {
                signed[id] = url
            }
        }
        return signed
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let int64 = value as? Int64 { return int64 }
        if let int = value as? Int { return Int64(int) }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String, let parsed = Int64(string) { return parsed }
        return nil
    }

    private static func dateValue(_ value: Any?, decoder: JSONDecoder) -> Date? {
        guard let string = value as? String,
              let data = try? JSONSerialization.data(withJSONObject: [string]),
              let dates = try? decoder.decode([Date].self, from: data) else {
            return nil
        }
        return dates.first
    }
}
