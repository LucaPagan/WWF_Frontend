//
//  DownloadPackage.swift
//  WWFChallenge7
//
//  SwiftData entity — mirrors Supabase table: public.download_packages
//  Represents a downloadable bundle (light/standard/full) for a trail.
//

import Foundation
import SwiftData

@Model
final class DownloadPackage {
    @Attribute(.unique) var id: UUID
    var pathId: UUID
    var tierRawValue: String
    var sizeBytes: Int64
    var includesVideo: Bool
    var includes3D: Bool
    var bundleURL: String?
    var isReady: Bool
    var manifestVersion: String
    var manifestSHA256: String?
    var assetCount: Int
    var generationStatus: String
    var generatedAt: Date?
    var errorMessage: String?
    var requiredAppVersion: String?
    var createdAt: Date
    var updatedAt: Date

    /// Local path where the bundle has been saved (nil = not yet downloaded)
    var localPath: String?
    var installedManifestSHA256: String?

    @Transient var tier: ContentTier {
        get { ContentTier(rawValue: tierRawValue) ?? .light }
        set { tierRawValue = newValue.rawValue }
    }

    var isDownloaded: Bool {
        guard let path = localPath else { return false }
        if path == "offline_ready" { return false }
        guard FileManager.default.fileExists(atPath: path) else { return false }
        if let remote = manifestSHA256, let installed = installedManifestSHA256 {
            return remote == installed
        }
        return manifestSHA256 == nil
    }

    var needsUpdate: Bool {
        guard let path = localPath,
              path != "offline_ready",
              FileManager.default.fileExists(atPath: path),
              let remote = manifestSHA256,
              let installed = installedManifestSHA256 else {
            return false
        }
        return remote != installed
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    init(
        pathId: UUID,
        tier: ContentTier = .light,
        sizeBytes: Int64 = 0,
        includesVideo: Bool = false,
        includes3D: Bool = false,
        bundleURL: String? = nil,
        isReady: Bool = false,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.pathId = pathId
        self.tierRawValue = tier.rawValue
        self.sizeBytes = sizeBytes
        self.includesVideo = includesVideo
        self.includes3D = includes3D
        self.bundleURL = bundleURL
        self.isReady = isReady
        self.manifestVersion = "1"
        self.manifestSHA256 = nil
        self.assetCount = 0
        self.generationStatus = isReady ? "ready" : "pending"
        self.generatedAt = nil
        self.errorMessage = nil
        self.requiredAppVersion = nil
        self.localPath = nil
        self.installedManifestSHA256 = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let t = data["tier"] as? String { tierRawValue = t }
        if let s = data["size_bytes"] as? Int64 { sizeBytes = s }
        if let s = data["size_bytes"] as? Int { sizeBytes = Int64(s) }
        if let v = data["includes_video"] as? Bool { includesVideo = v }
        if let m = data["includes_3d"] as? Bool { includes3D = m }
        bundleURL = data["bundle_url"] as? String
        if let r = data["is_ready"] as? Bool { isReady = r }
        if let version = data["manifest_version"] as? String { manifestVersion = version }
        manifestSHA256 = data["manifest_sha256"] as? String
        if let count = data["asset_count"] as? Int { assetCount = count }
        if let status = data["generation_status"] as? String { generationStatus = status }
        if let required = data["required_app_version"] as? String { requiredAppVersion = required }
        errorMessage = data["error_message"] as? String
        if localPath == "offline_ready" {
            localPath = nil
        }
    }
}
