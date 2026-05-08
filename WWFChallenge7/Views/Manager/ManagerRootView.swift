import SwiftUI

struct ManagerRootView: View {
    @EnvironmentObject var managerSession: ManagerSession
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapEditorView()
                .tabItem {
                    Label("Mappa", systemImage: "map.fill")
                }
                .tag(0)

            TrailBuilderListView()
                .tabItem {
                    Label("Percorsi", systemImage: "signpost.right.and.left.fill")
                }
                .tag(1)

            ManagerSettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(Color("WWFGreen"))
    }
}