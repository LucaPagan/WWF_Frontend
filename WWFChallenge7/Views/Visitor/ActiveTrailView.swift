//
//  ActiveTrailView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

struct ActiveTrailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss

    // Set degli ID dei POI già scansionati
    @State private var completedPOIIds: Set<UUID> = []
    @State private var currentPOIPosition: CGPoint? = nil     // posizione normalizzata (0-1) del POI attuale
    @State private var showScanner = false
    @State private var scannedPOI: POI? = nil
    @State private var showPOIModal = false
    @State private var showCompletionAlert = false
    @State private var mapSize: CGSize = .zero

    // Il prossimo step da completare
    var currentStep: TrailStep? {
        trail.currentStep(completedPOIIds: completedPOIIds)
    }

    var progressFraction: Double {
        guard !trail.steps.isEmpty else { return 0 }
        return Double(completedPOIIds.count) / Double(trail.steps.count)
    }

    var isCompleted: Bool {
        completedPOIIds.count >= trail.steps.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: Mappa
            GeometryReader { geo in
                ZStack {
                    // ── Placeholder mappa ──────────────────────────────────────
                    // Sostituire Image("map_placeholder") con la tua mappa reale.
                    // L'immagine deve chiamarsi "astroni_map" negli Assets.xcassets
                    // oppure usa un PDF: Image("astroni_map").resizable()
                    // ──────────────────────────────────────────────────────────
                    MapPlaceholderView()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .onAppear { mapSize = geo.size }

                    // Overlay POI sul percorso
                    ForEach(trail.sortedSteps) { step in
                        if let poi = step.poi {
                            POIMarkerView(
                                poi: poi,
                                isCompleted: completedPOIIds.contains(poi.id),
                                isCurrent: currentStep?.poi?.id == poi.id
                            )
                            .position(
                                x: poi.x * geo.size.width,
                                y: poi.y * geo.size.height
                            )
                        }
                    }

                    // Linea del percorso
                    TrailPathOverlay(
                        steps: trail.sortedSteps,
                        completedPOIIds: completedPOIIds,
                        size: geo.size
                    )
                }
            }
            .ignoresSafeArea()

            // MARK: Pannello inferiore
            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(fraction: progressFraction)
                    .frame(height: 4)

                VStack(spacing: 16) {
                    // Step corrente
                    if let step = currentStep {
                        CurrentStepCard(step: step)
                    } else if isCompleted {
                        CompletedBanner()
                    }

                    // Bottone scansiona QR
                    if !isCompleted {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scansiona QR Code", systemImage: "qrcode.viewfinder")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("WWFGreen"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Label("Torna alla home", systemImage: "house.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("WWFDarkGreen"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding()
                .background(
                    Color(.systemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(radius: 12)
                )
            }
        }
        .overlay(alignment: .topLeading) {
            // Bottone chiudi
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, Color.black.opacity(0.4))
                    .padding()
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { payload in
                handleQRScan(payload: payload)
            }
        }
        .sheet(item: $scannedPOI) { poi in
            POIModalView(poi: poi)
        }
    }

    // MARK: - QR Scan Handler

    private func handleQRScan(payload: String) {
        showScanner = false

        // Cerca il POI corrispondente al payload scansionato
        let allPOIs = trail.sortedSteps.compactMap { $0.poi }
        guard let matched = allPOIs.first(where: { $0.qrPayload == payload }) else {
            // QR non riconosciuto — potresti mostrare un alert
            return
        }

        // Aggiorna posizione e segna come completato
        completedPOIIds.insert(matched.id)
        scannedPOI = matched

        if isCompleted {
            showCompletionAlert = true
        }
    }
}

// MARK: - Subviews

struct MapPlaceholderView: View {
    var body: some View {
        // ─────────────────────────────────────────────────────────────────
        // ISTRUZIONI PER INSERIRE LA MAPPA REALE:
        //
        // 1. Aggiungi il file immagine (PNG/PDF) agli Assets.xcassets
        //    con il nome "astroni_map"
        //
        // 2. Sostituisci questo intero blocco con:
        //    Image("astroni_map")
        //        .resizable()
        //        .scaledToFill()
        //        .clipped()
        //
        // 3. Le coordinate x/y dei POI sono normalizzate (0.0 → 1.0)
        //    rispetto alla dimensione della mappa. Calibra i valori
        //    nei POI di conseguenza.
        // ─────────────────────────────────────────────────────────────────
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.38, blue: 0.18),
                    Color(red: 0.28, green: 0.52, blue: 0.22),
                    Color(red: 0.38, green: 0.62, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Griglia placeholder
            Canvas { context, size in
                let step: CGFloat = 60
                var x: CGFloat = 0
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
                    x += step
                }
                var y: CGFloat = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
                    y += step
                }
            }

            VStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.3))
                Text("Mappa Oasi degli Astroni")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Text("Inserire asset «astroni_map»")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.25))
            }
        }
    }
}

struct POIMarkerView: View {
    let poi: POI
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        ZStack {
            if isCurrent {
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isCurrent ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: isCurrent)
            }

            Circle()
                .fill(isCompleted ? Color.gray : (isCurrent ? Color.yellow : Color("WWFGreen")))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: isCompleted ? "checkmark" : poi.type.icon)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .shadow(radius: 3)
        }
    }
}

struct TrailPathOverlay: View {
    let steps: [TrailStep]
    let completedPOIIds: Set<UUID>
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let points: [CGPoint] = steps.compactMap { step in
                guard let poi = step.poi else { return nil }
                return CGPoint(x: poi.x * size.width, y: poi.y * size.height)
            }

            guard points.count >= 2 else { return }

            for i in 0..<(points.count - 1) {
                var path = Path()
                path.move(to: points[i])
                path.addLine(to: points[i + 1])

                let fromPOI = steps[i].poi
                let isDone = fromPOI.map { completedPOIIds.contains($0.id) } ?? false

                context.stroke(
                    path,
                    with: .color(isDone ? Color.gray.opacity(0.5) : Color("WWFGreen").opacity(0.7)),
                    style: StrokeStyle(lineWidth: 3, dash: isDone ? [] : [8, 4])
                )
            }
        }
    }
}

struct CurrentStepCard: View {
    let step: TrailStep

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                .font(.title2)
                .foregroundColor(Color("WWFGreen"))

            VStack(alignment: .leading, spacing: 2) {
                if let poi = step.poi {
                    Text("Prossima tappa: \(poi.name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(step.instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding()
        .background(Color("WWFGreen").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CompletedBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Percorso completato!")
                    .fontWeight(.bold)
                Text("Hai visitato tutte le tappe dell'Oasi.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ProgressBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.gray.opacity(0.2))
                Rectangle()
                    .fill(Color("WWFGreen"))
                    .frame(width: geo.size.width * fraction)
                    .animation(.spring(), value: fraction)
            }
        }
    }
}