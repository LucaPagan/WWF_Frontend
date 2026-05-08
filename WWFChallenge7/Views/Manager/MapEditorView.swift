import SwiftUI
import SwiftData

struct MapEditorView: View {
    @Environment(\.modelContext) private var context
    @Query private var allPOIs: [POI]

    @State private var showPOIEditor = false
    @State private var pendingPosition: CGPoint? = nil     // coordinate normalizzate tap
    @State private var selectedPOI: POI? = nil
    @State private var mapSize: CGSize = .zero
    @State private var showDeleteConfirm = false
    @State private var poiToDelete: POI? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: Mappa con gesture tap
                GeometryReader { geo in
                    ZStack {
                        // ── Inserire qui la mappa reale ───────────────────────
                        // Stessa logica di ActiveTrailView:
                        // Image("astroni_map").resizable().scaledToFill().clipped()
                        // ─────────────────────────────────────────────────────
                        MapPlaceholderView()
                            .onAppear { mapSize = geo.size }

                        // Tap per creare nuovo POI
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                // Normalizza le coordinate rispetto alla dimensione mappa
                                let normalized = CGPoint(
                                    x: location.x / geo.size.width,
                                    y: location.y / geo.size.height
                                )
                                pendingPosition = normalized
                                selectedPOI = nil
                                showPOIEditor = true
                            }

                        // Marker POI esistenti
                        ForEach(allPOIs) { poi in
                            POIEditorMarker(poi: poi, isSelected: selectedPOI?.id == poi.id)
                                .position(
                                    x: poi.x * geo.size.width,
                                    y: poi.y * geo.size.height
                                )
                                .onTapGesture {
                                    selectedPOI = poi
                                    showPOIEditor = true
                                }
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                // MARK: Legenda tipi POI
                VStack {
                    Spacer()
                    POILegendView()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Editor Mappa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(allPOIs.count) POI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showPOIEditor) {
                if let existing = selectedPOI {
                    // Modifica POI esistente
                    POIEditorView(
                        mode: .edit(existing),
                        onSave: { handleSave($0) },
                        onDelete: { handleDelete($0) }
                    )
                } else if let pos = pendingPosition {
                    // Crea nuovo POI nel punto tappato
                    POIEditorView(
                        mode: .create(x: pos.x, y: pos.y),
                        onSave: { handleSave($0) },
                        onDelete: nil
                    )
                }
            }
        }
    }

    // MARK: - Handlers

    private func handleSave(_ poi: POI) {
        context.insert(poi)
        try? context.save()
        showPOIEditor = false
        selectedPOI = nil
        pendingPosition = nil
    }

    private func handleDelete(_ poi: POI) {
        context.delete(poi)
        try? context.save()
        showPOIEditor = false
        selectedPOI = nil
    }
}

// MARK: - Marker editor

struct POIEditorMarker: View {
    let poi: POI
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: 44, height: 44)
            }
            Circle()
                .fill(Color(hex: poi.type.color) ?? .green)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: poi.type.icon)
                        .font(.caption)
                        .foregroundColor(.white)
                )
                .shadow(radius: 4)

            // Etichetta nome
            Text(poi.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .offset(y: 22)
        }
    }
}

// MARK: - Legenda

struct POILegendView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(POIType.allCases, id: \.self) { type in
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.caption2)
                            .foregroundColor(Color(hex: type.color) ?? .green)
                        Text(type.rawValue)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(radius: 2)
                }
            }
            .padding(.horizontal)
        }
    }
}