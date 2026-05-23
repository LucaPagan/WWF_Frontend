//
//  WWFChallenge7App.swift
//  WWFChallenge7
//
//  App entry point — Clean Architecture aligned.
//  Initialises SwiftData with all entities, injects SyncManager,
//  DownloadManager, and UserSession into the environment.
//

import SwiftUI
import SwiftData
import Combine

@main
struct WWFChallenge7App: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Trail.self,
                POI.self,
                TrailStep.self,
                Event.self,
                Content.self,
                DownloadPackage.self,
                UserProfile.self,
                LocalTranslation.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // If migration fails, delete the store and restart clean
            Self.deleteStore()
            do {
                let schema = Schema([
                    Trail.self,
                    POI.self,
                    TrailStep.self,
                    Event.self,
                    Content.self,
                    DownloadPackage.self,
                    UserProfile.self,
                    LocalTranslation.self
                ])
                let config = ModelConfiguration(schema: schema)
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData container failed anche dopo reset: \(error)")
            }
        }
    }

    @StateObject private var syncManager = SyncManager()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var userSession = UserSession()
    @StateObject private var accessibilityPreferences = AccessibilityPreferences()

    var body: some Scene {
        WindowGroup {
            VisitorRootView()
                .modelContainer(container)
                .environmentObject(syncManager)
                .environmentObject(downloadManager)
                .environmentObject(userSession)
                .environmentObject(accessibilityPreferences)
                .task {
                    // 1. Configure managers with model context
                    syncManager.configure(with: container.mainContext)
                    downloadManager.configure(with: container.mainContext)
                    LocalizationManager.shared.configure(with: container)

                    // 2. Ensure anonymous profile exists
                    await userSession.ensureAnonymousProfile()

                    // 3. Restore any existing auth session
                    await userSession.restoreSession()

                    // 4. Seed data if needed (first launch / empty store)
                    DataService.seedIfNeeded(context: container.mainContext)

                    // 5. Pull latest data from Supabase
                    await syncManager.pullLatestData()
                }
        }
    }

    // MARK: - Store Reset

    private static func deleteStore() {
        let urls = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let base = urls.first else { return }

        let storeFiles = [
            "default.store",
            "default.store-shm",
            "default.store-wal"
        ]
        for file in storeFiles {
            let url = base.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
