import CryptoKit
import Foundation
import SwiftData
import Combine

enum OfflineDownloadError: LocalizedError {
    case packageNotReady
    case insufficientSpace(required: Int64, available: Int64)
    case missingSignedURL(String)
    case checksumMismatch(String)
    case invalidManifest
    case cannotCommit

    var errorDescription: String? {
        switch self {
        case .packageNotReady:
            return "Il bundle non e ancora pronto per il download."
        case .insufficientSpace(let required, let available):
            return "Spazio insufficiente. Richiesti \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), disponibili \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))."
        case .missingSignedURL(let asset):
            return "URL temporaneo mancante per \(asset)."
        case .checksumMismatch(let asset):
            return "Verifica integrita fallita per \(asset)."
        case .invalidManifest:
            return "Manifest bundle non valido."
        case .cannotCommit:
            return "Impossibile finalizzare il bundle offline."
        }
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published var isDownloading: Bool = false
    @Published var progress: Double = 0
    @Published var currentDownloadName: String?
    @Published var error: String?

    private var modelContainer: ModelContainer?
    private let bundleClient = BundleClient()
    private let fileManager = FileManager.default
    private let maxAttempts = 3

    func configure(with context: ModelContext) {
        self.modelContainer = context.container
        recoverInterruptedDownloads()
    }

    func downloadPackage(_ pkg: DownloadPackage, language: String) async {
        isDownloading = true
        progress = 0
        currentDownloadName = "Preparazione \(pkg.tier.displayName)..."
        error = nil
        UserDefaults.standard.set(language, forKey: "preferredLanguage")

        do {
            guard pkg.isReady, pkg.generationStatus == "ready", pkg.manifestSHA256 != nil else {
                throw OfflineDownloadError.packageNotReady
            }

            var envelope = try await retrying("manifest") {
                try await self.bundleClient.fetchBundle(pathId: pkg.pathId, tier: pkg.tier)
            }

            guard envelope.manifest.pathId == pkg.pathId,
                  envelope.manifest.tier == pkg.tier,
                  envelope.manifest.manifestSHA256 == pkg.manifestSHA256 else {
                throw OfflineDownloadError.invalidManifest
            }

            try ensureAvailableSpace(requiredBytes: pkg.sizeBytes)

            let dirs = try directories(for: pkg, manifestSHA: envelope.manifest.manifestSHA256)
            try fileManager.createDirectory(at: dirs.staging, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dirs.staging.appendingPathComponent("media", isDirectory: true), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dirs.staging.appendingPathComponent("poi_photos", isDirectory: true), withIntermediateDirectories: true)

            let state = loadState(at: dirs.stateURL)
                ?? BundleDownloadState(packageId: pkg.id, manifestSHA256: envelope.manifest.manifestSHA256, completedAssetIds: [], updatedAt: Date())
            var completed = state.completedAssetIds

            try saveManifest(envelope.manifest, to: dirs.manifestURL)

            let assets = envelope.manifest.assets
            let totalUnits = max(assets.count, 1)

            for (index, asset) in assets.enumerated() {
                if completed.contains(asset.id), try assetIsValid(asset, baseURL: dirs.staging) {
                    progress = Double(index + 1) / Double(totalUnits)
                    continue
                }

                currentDownloadName = "Scaricamento \(asset.localRelativePath)..."
                var assetURL = try await signedURL(for: asset, envelope: &envelope, package: pkg)
                do {
                    try await download(asset: asset, signedURL: assetURL, baseURL: dirs.staging)
                } catch {
                    let refreshed = try await bundleClient.refreshSignedAssets(pathId: pkg.pathId, tier: pkg.tier)
                    envelope = BundleEnvelope(manifest: envelope.manifest, signedAssets: refreshed)
                    assetURL = try await signedURL(for: asset, envelope: &envelope, package: pkg)
                    try await download(asset: asset, signedURL: assetURL, baseURL: dirs.staging)
                }
                completed.insert(asset.id)
                saveState(BundleDownloadState(packageId: pkg.id, manifestSHA256: envelope.manifest.manifestSHA256, completedAssetIds: completed, updatedAt: Date()), at: dirs.stateURL)
                progress = Double(index + 1) / Double(totalUnits)
            }

            currentDownloadName = "Verifica integrita..."
            for asset in assets {
                guard try assetIsValid(asset, baseURL: dirs.staging) else {
                    throw OfflineDownloadError.checksumMismatch(asset.localRelativePath)
                }
            }

            currentDownloadName = "Salvataggio offline..."
            let installedURL = try commit(staging: dirs.staging, installed: dirs.installed)
            try persist(manifest: envelope.manifest, package: pkg, installedURL: installedURL)
            try? fileManager.removeItem(at: dirs.stateURL)

            progress = 1
        } catch {
            self.error = error.localizedDescription
            if let dirs = try? directories(for: pkg, manifestSHA: pkg.manifestSHA256 ?? "unknown") {
                try? fileManager.removeItem(at: dirs.staging)
            }
        }

        isDownloading = false
        currentDownloadName = nil
    }

    func packages(forTrailId trailId: UUID) -> [DownloadPackage] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DownloadPackage>(
            predicate: #Predicate { $0.pathId == trailId && $0.isReady == true && $0.generationStatus == "ready" },
            sortBy: [SortDescriptor(\DownloadPackage.sizeBytes)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func recoverInterruptedDownloads() {
        guard let root = try? offlineRoot() else { return }
        let staging = root.appendingPathComponent(".staging", isDirectory: true)
        guard let items = try? fileManager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) else { return }
        for item in items {
            let state = item.appendingPathComponent("download-state.json")
            if !fileManager.fileExists(atPath: state.path) {
                try? fileManager.removeItem(at: item)
            }
        }
    }

    private func signedURL(for asset: OfflineBundleAsset, envelope: inout BundleEnvelope, package: DownloadPackage) async throws -> String {
        if let url = envelope.signedAssets[asset.id] {
            return url
        }
        let refreshed = try await bundleClient.refreshSignedAssets(pathId: package.pathId, tier: package.tier)
        envelope = BundleEnvelope(manifest: envelope.manifest, signedAssets: refreshed)
        guard let url = refreshed[asset.id] else {
            throw OfflineDownloadError.missingSignedURL(asset.id)
        }
        return url
    }

    private func download(asset: OfflineBundleAsset, signedURL: String, baseURL: URL) async throws {
        let destination = baseURL.appendingPathComponent(asset.localRelativePath)
        let partial = destination.appendingPathExtension("part")
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let data = try await SupabaseConfig.shared.downloadSignedURL(signedURL)
                try data.write(to: partial, options: .atomic)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: partial, to: destination)
                guard try assetIsValid(asset, baseURL: baseURL) else {
                    throw OfflineDownloadError.checksumMismatch(asset.localRelativePath)
                }
                return
            } catch {
                lastError = error
                try? fileManager.removeItem(at: partial)
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 350_000_000)
                }
            }
        }
        throw lastError ?? OfflineDownloadError.checksumMismatch(asset.localRelativePath)
    }

    private func assetIsValid(_ asset: OfflineBundleAsset, baseURL: URL) throws -> Bool {
        let url = baseURL.appendingPathComponent(asset.localRelativePath)
        guard fileManager.fileExists(atPath: url.path) else { return false }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size == asset.sizeBytes else { return false }
        let data = try Data(contentsOf: url)
        return sha256(data) == asset.sha256
    }

    private func commit(staging: URL, installed: URL) throws -> URL {
        if fileManager.fileExists(atPath: installed.path) {
            try fileManager.removeItem(at: installed)
        }
        try fileManager.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: staging, to: installed)
        guard fileManager.fileExists(atPath: installed.path) else {
            throw OfflineDownloadError.cannotCommit
        }
        return installed
    }

    private func persist(manifest: OfflineBundleManifest, package: DownloadPackage, installedURL: URL) throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let packageId = package.id

        let pkgDescriptor = FetchDescriptor<DownloadPackage>(predicate: #Predicate { $0.id == packageId })
        let localPackage = try context.fetch(pkgDescriptor).first ?? package
        if localPackage.modelContext == nil {
            context.insert(localPackage)
        }
        localPackage.localPath = installedURL.path
        localPackage.manifestSHA256 = manifest.manifestSHA256
        localPackage.manifestVersion = manifest.manifestVersion
        localPackage.assetCount = manifest.assets.count
        localPackage.generationStatus = "ready"

        try upsertPath(manifest.path, context: context)
        try upsertPOIs(manifest.pois + manifest.globalAlerts, context: context)
        try upsertSteps(manifest.pathSteps, pathId: manifest.pathId, context: context)
        try upsertContents(manifest.contents, manifest: manifest, packageId: packageId, installedURL: installedURL, context: context)
        try upsertTranslations(manifest.translations, context: context)
        try applyPOIPhotos(manifest.assets, installedURL: installedURL, context: context)

        let install = LocalBundleInstall(
            packageId: packageId,
            pathId: manifest.pathId,
            tier: manifest.tier,
            manifestSHA256: manifest.manifestSHA256,
            installPath: installedURL.path,
            sizeBytes: localPackage.sizeBytes
        )
        context.insert(install)
        try context.save()
    }

    private func upsertPath(_ data: [String: JSONValue], context: ModelContext) throws {
        guard let id = uuid(data["id"]) else { return }
        let descriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == id })
        let trail = try context.fetch(descriptor).first ?? Trail(
            name: string(data["name"]) ?? "",
            description: string(data["description"]) ?? "",
            fixedID: id
        )
        if trail.modelContext == nil { context.insert(trail) }
        trail.updateFromRemote(data.foundationDictionary)
    }

    private func upsertPOIs(_ pois: [[String: JSONValue]], context: ModelContext) throws {
        for data in pois {
            guard let id = uuid(data["id"]) else { continue }
            let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.updateFromRemote(data.foundationDictionary)
            } else if let newPOI = createPOI(data) {
                context.insert(newPOI)
            }
        }
    }

    private func upsertSteps(_ steps: [[String: JSONValue]], pathId: UUID, context: ModelContext) throws {
        let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == pathId })
        guard let trail = try context.fetch(trailDescriptor).first else { return }

        for data in steps {
            guard let id = uuid(data["id"]), let poiId = uuid(data["poi_id"]) else { continue }
            let stepDescriptor = FetchDescriptor<TrailStep>(predicate: #Predicate { $0.id == id })
            let poiDescriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })
            guard let poi = try context.fetch(poiDescriptor).first else { continue }

            let step = try context.fetch(stepDescriptor).first ?? TrailStep(stepOrder: int(data["step_order"]) ?? 0, poi: poi, fixedID: id)
            if step.modelContext == nil {
                context.insert(step)
                trail.steps.append(step)
            }
            step.stepOrder = int(data["step_order"]) ?? step.stepOrder
            step.directionHint = string(data["direction_hint"]) ?? step.directionHint
            step.distanceMeters = int(data["distance_meters"]) ?? step.distanceMeters
            step.estimatedMinutes = int(data["estimated_minutes"]) ?? step.estimatedMinutes
            step.pathGeometry = string(data["path_geometry"])
            step.poi = poi
            if !trail.steps.contains(where: { $0.id == step.id }) {
                trail.steps.append(step)
            }
        }
    }

    private func upsertContents(_ contents: [[String: JSONValue]], manifest: OfflineBundleManifest, packageId: UUID, installedURL: URL, context: ModelContext) throws {
        for data in contents {
            guard let id = uuid(data["id"]), let poiId = uuid(data["poi_id"]) else { continue }
            let descriptor = FetchDescriptor<Content>(predicate: #Predicate { $0.id == id })
            let content = try context.fetch(descriptor).first ?? Content(
                poiId: poiId,
                type: ContentType(rawValue: string(data["type"]) ?? "text") ?? .text,
                tier: ContentTier(rawValue: string(data["tier"]) ?? "light") ?? .light,
                fixedID: id
            )
            if content.modelContext == nil { context.insert(content) }
            content.updateFromRemote(data.foundationDictionary)
            content.installedPackageId = packageId
            if let asset = manifest.assets.first(where: { $0.contentId == id }) {
                content.localFilePath = installedURL.appendingPathComponent(asset.localRelativePath).path
            }
        }
    }

    private func upsertTranslations(_ translations: [[String: JSONValue]], context: ModelContext) throws {
        for data in translations {
            guard let id = uuid(data["id"]),
                  let recordId = uuid(data["record_id"]),
                  let tableName = string(data["table_name"]),
                  let fieldName = string(data["field_name"]),
                  let languageCode = string(data["language_code"]),
                  let translatedText = string(data["translated_text"]) else { continue }

            let descriptor = FetchDescriptor<LocalTranslation>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.tableName = tableName
                existing.recordId = recordId
                existing.fieldName = fieldName
                existing.languageCode = languageCode
                existing.translatedText = translatedText
            } else {
                context.insert(LocalTranslation(
                    tableName: tableName,
                    recordId: recordId,
                    fieldName: fieldName,
                    languageCode: languageCode,
                    translatedText: translatedText,
                    fixedID: id
                ))
            }
        }
    }

    private func applyPOIPhotos(_ assets: [OfflineBundleAsset], installedURL: URL, context: ModelContext) throws {
        for asset in assets where asset.kind == "poi_photo" {
            guard let poiId = asset.poiId else { continue }
            let descriptor = FetchDescriptor<POI>(predicate: #Predicate { $0.id == poiId })
            guard let poi = try context.fetch(descriptor).first else { continue }
            let url = installedURL.appendingPathComponent(asset.localRelativePath)
            poi.photoData = try? Data(contentsOf: url)
        }
    }

    private func createPOI(_ data: [String: JSONValue]) -> POI? {
        guard let id = uuid(data["id"]),
              let name = string(data["name"]),
              let description = string(data["poi_description"]),
              let x = double(data["x"]),
              let y = double(data["y"]) else { return nil }
        let poi = POI(
            name: name,
            description: description,
            x: x,
            y: y,
            latitude: double(data["latitude"]),
            longitude: double(data["longitude"]),
            type: POIType(rawValue: string(data["type"]) ?? "landmark") ?? .landmark,
            photoURL: string(data["photo_url"]),
            isStartPoint: bool(data["is_start_point"]) ?? false,
            isActive: bool(data["is_active"]) ?? true,
            iconName: string(data["icon_name"]),
            numericCode: string(data["numeric_code"]),
            descriptionKids: string(data["description_kids"]),
            descriptionEasyRead: string(data["description_easy_read"]),
            fixedID: id
        )
        poi.qrPayload = string(data["qr_payload"]) ?? poi.qrPayload
        poi.needsSync = false
        return poi
    }

    private func saveManifest(_ manifest: OfflineBundleManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    private func loadState(at url: URL) -> BundleDownloadState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BundleDownloadState.self, from: data)
    }

    private func saveState(_ state: BundleDownloadState, at url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func ensureAvailableSpace(requiredBytes: Int64) throws {
        let root = try offlineRoot()
        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let required = Int64(Double(requiredBytes) * 1.1)
        guard available >= required else {
            throw OfflineDownloadError.insufficientSpace(required: required, available: available)
        }
    }

    private func retrying<T>(_ label: String, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                if attempt > 1 { currentDownloadName = "Retry \(label)..." }
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                }
            }
        }
        throw lastError ?? OfflineDownloadError.invalidManifest
    }

    private func directories(for package: DownloadPackage, manifestSHA: String) throws -> (root: URL, staging: URL, installed: URL, manifestURL: URL, stateURL: URL) {
        let root = try offlineRoot()
        let staging = root.appendingPathComponent(".staging/\(package.id.uuidString)", isDirectory: true)
        let installed = root.appendingPathComponent("installed/\(package.id.uuidString)-\(manifestSHA)", isDirectory: true)
        return (
            root,
            staging,
            installed,
            staging.appendingPathComponent("manifest.json"),
            staging.appendingPathComponent("download-state.json")
        )
    }

    private func offlineRoot() throws -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = documents.appendingPathComponent("OfflineBundles", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func string(_ value: JSONValue?) -> String? { value?.stringValue }
    private func int(_ value: JSONValue?) -> Int? { value?.intValue }
    private func double(_ value: JSONValue?) -> Double? { value?.doubleValue }
    private func bool(_ value: JSONValue?) -> Bool? { value?.boolValue }
    private func uuid(_ value: JSONValue?) -> UUID? {
        guard let raw = value?.stringValue else { return nil }
        return UUID(uuidString: raw)
    }
}
