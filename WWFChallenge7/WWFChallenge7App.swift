import SwiftUI
import SwiftData

@main
struct WWFChallenge7App: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Trail.self, POI.self, TrailStep.self)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}