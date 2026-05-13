import SwiftUI
import SwiftData

@main
struct WWFChallenge7App: App {
    let container: ModelContainer

    init() {
        do {
            // Configurazione con migrazione automatica abilitata
            let schema = Schema([Trail.self, POI.self, TrailStep.self, Event.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Se la migrazione fallisce, cancella lo store e riparte pulito
            // Questo elimina tutti i dati salvati — ok per prototipo
            Self.deleteStore()
            do {
                let schema = Schema([Trail.self, POI.self, TrailStep.self, Event.self])
                let config = ModelConfiguration(schema: schema)
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData container failed anche dopo reset: \(error)")
            }
        }
    }

    @StateObject private var syncManager = SyncManager()

    var body: some Scene {
        WindowGroup {
            VisitorRootView()
                .modelContainer(container)
                .environmentObject(syncManager)
                .task {
                    syncManager.configure(with: container.mainContext)
                    await syncManager.pullLatestData()
                }
        }
    }

    // Cancella il file .store dal disco
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
