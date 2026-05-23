//
//  DownloadManager.swift
//  WWFChallenge7
//
//  Manages tier-based content downloads from Supabase Storage.
//  Saves bundles to the app's local Documents directory and
//  tracks download state in SwiftData (DownloadPackage.localPath).
//

import Foundation
import SwiftData
import Combine

@MainActor
final class DownloadManager: ObservableObject {

    @Published var isDownloading: Bool = false
    @Published var progress: Double = 0
    @Published var currentDownloadName: String?
    @Published var error: String?

    private var modelContainer: ModelContainer?

    func configure(with context: ModelContext) {
        self.modelContainer = context.container
    }

    /// Downloads a package bundle from Supabase Storage and saves it locally.
    /// Also handles language-specific filtering if applicable.
    func downloadPackage(_ pkg: DownloadPackage, language: String) async {
        isDownloading = true
        progress = 0
        currentDownloadName = "Inizializzazione \(pkg.tier.displayName)..."
        error = nil

        do {
            // 0. Update preferred language selection
            UserDefaults.standard.set(language, forKey: "preferredLanguage")
            
            // 0.5. Pre-cache translations matching this language
            currentDownloadName = "Scaricamento traduzioni (\(language.uppercased()))..."
            let queryStr = "select=*&language_code=in.(it,\(language))"
            if let remoteTrans = try? await SupabaseConfig.shared.fetch(from: "translations", query: queryStr),
               let container = modelContainer {
                let context = ModelContext(container)
                for data in remoteTrans {
                    guard let idStr = data["id"] as? String, let remoteId = UUID(uuidString: idStr) else { continue }
                    guard let tableName = data["table_name"] as? String,
                          let recordIdStr = data["record_id"] as? String, let recordId = UUID(uuidString: recordIdStr),
                          let fieldName = data["field_name"] as? String,
                          let langCode = data["language_code"] as? String,
                          let rawTranslatedText = data["translated_text"] as? String else { continue }
                    
                    let translatedText = rawTranslatedText
                    
                    let desc = FetchDescriptor<LocalTranslation>(predicate: #Predicate { $0.id == remoteId })
                    if let existing = try? context.fetch(desc).first {
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
                        context.insert(trans)
                    }
                }
                try? context.save()
            }

            // 1. Fetch all contents for this trail and tier
            // We follow the inclusive logic: Light < Standard < Full
            let contents = try await fetchContentsForTier(pkg.tier, trailId: pkg.pathId)
            
            let totalCount = contents.count
            var completedCount = 0
            
            if totalCount > 0 {
                for content in contents {
                    currentDownloadName = "Scaricamento \(content.contentType.displayName)..."
                    
                    // If it's text, we save the localized version to local storage
                    if content.contentType == .text {
                        if let localizedData = content.data {
                            // Extract specific language if possible, otherwise keep all
                            // In this POC, we'll just save the data as is
                        }
                    } else if let fileURL = content.fileURL {
                        let data = try await SupabaseConfig.shared.downloadFile(from: fileURL)
                        _ = try saveToDocuments(
                            data: data,
                            filename: content.localFileName
                        )
                    }
                    
                    completedCount += 1
                    progress = Double(completedCount) / Double(totalCount)
                }
            } else {
                progress = 1.0
            }

            // Update SwiftData record
            if let container = modelContainer {
                let context = ModelContext(container)
                
                // 1. Fetch or insert the package in this specific context so it persists!
                let pkgId = pkg.id
                let pkgDescriptor = FetchDescriptor<DownloadPackage>(predicate: #Predicate { $0.id == pkgId })
                if let existingPkg = try? context.fetch(pkgDescriptor).first {
                    existingPkg.localPath = "offline_ready"
                } else {
                    pkg.localPath = "offline_ready"
                    context.insert(pkg)
                }

                // 2. Fetch or insert all Content items in this context so they persist!
                for content in contents {
                    let contentId = content.id
                    let contentDescriptor = FetchDescriptor<Content>(predicate: #Predicate { $0.id == contentId })
                    if let existingContent = try? context.fetch(contentDescriptor).first {
                        existingContent.updateFromRemote([
                            "type": content.typeRawValue,
                            "tier": content.tierRawValue,
                            "file_url": content.fileURL ?? "",
                            "sort_order": content.sortOrder
                        ])
                        existingContent.data = content.data
                    } else {
                        context.insert(content)
                    }
                }

                // 3. Cache main POI photos for the trail
                let trailId = pkg.pathId
                let trailDescriptor = FetchDescriptor<Trail>(predicate: #Predicate { $0.id == trailId })
                if let trails = try? context.fetch(trailDescriptor), let trail = trails.first {
                    for step in trail.steps {
                        if let poi = step.poi, let photoURL = poi.photoURL, poi.photoData == nil {
                            currentDownloadName = "Scaricamento copertina \(poi.name)..."
                            if let data = try? await SupabaseConfig.shared.downloadFile(from: photoURL) {
                                poi.photoData = data
                            }
                        }
                    }
                }
                
                try context.save()
            }

            progress = 1.0
        } catch {
            self.error = "Download fallito: \(error.localizedDescription)"
        }

        isDownloading = false
        currentDownloadName = nil
    }

    private func fetchContentsForTier(_ tier: ContentTier, trailId: UUID) async throws -> [Content] {
        // Inclusive tiers logic
        let tiers: [String]
        switch tier {
        case .light:    tiers = ["light"]
        case .standard: tiers = ["light", "standard"]
        case .full:     tiers = ["light", "standard", "full"]
        }
        
        let filter = "tier=in.(\(tiers.joined(separator: ",")))"
        // In a real scenario, we'd join with path_steps to get only relevant POIs
        // For now, let's fetch all contents and filter in-memory or via simple query
        let remoteData = try await SupabaseConfig.shared.fetch(from: "contents", query: "select=*&\(filter)")
        
        return remoteData.compactMap { data in
            guard let idStr = data["id"] as? String, let id = UUID(uuidString: idStr),
                  let poiIdStr = data["poi_id"] as? String, let poiId = UUID(uuidString: poiIdStr) else { return nil }
            let c = Content(poiId: poiId, fixedID: id)
            c.updateFromRemote(data)
            return c
        }
    }

    /// Returns available download packages for a trail, grouped by tier.
    func packages(forTrailId trailId: UUID) -> [DownloadPackage] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DownloadPackage>(
            predicate: #Predicate { $0.pathId == trailId && $0.isReady == true },
            sortBy: [SortDescriptor(\DownloadPackage.sizeBytes)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    private func saveToDocuments(data: Data, filename: String) throws -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDir = documentsDir.appendingPathComponent("OfflineContent", isDirectory: true)

        let fileURL = baseDir.appendingPathComponent(filename)
        let parentDir = fileURL.deletingLastPathComponent()
        
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try data.write(to: fileURL)
        return fileURL
    }
}
