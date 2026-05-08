//
//  MapPlaceholderView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

// MARK: - Mappa placeholder
// Sostituire MapPlaceholderView() con Image("astroni_map")
// quando l'asset è pronto

struct MapPlaceholderView: View {
    var body: some View {
        Image("astroni_map")
            .resizable()
            .scaledToFill()
            .clipped()
    }
}

// MARK: - Linea percorso sulla mappa

struct TrailPathOverlay: View {
    let trail: Trail
    let completedPOIIds: Set<UUID>
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            var points: [CGPoint] = [
                CGPoint(x: trail.startX * size.width, y: trail.startY * size.height)
            ]
            points += trail.sortedSteps.compactMap { step in
                guard let poi = step.poi else { return nil }
                return CGPoint(x: poi.x * size.width, y: poi.y * size.height)
            }

            guard points.count >= 2 else { return }

            for i in 0..<(points.count - 1) {
                var path = Path()
                path.move(to: points[i])
                path.addLine(to: points[i + 1])

                // Il tratto è grigio se il segmento è già percorso
                let segmentCompleted: Bool = {
                    guard i > 0 else {
                        return trail.sortedSteps.first?.poi
                            .map { completedPOIIds.contains($0.id) } ?? false
                    }
                    let fromPOI = trail.sortedSteps[i - 1].poi
                    return fromPOI.map { completedPOIIds.contains($0.id) } ?? false
                }()

                context.stroke(
                    path,
                    with: .color(
                        segmentCompleted
                            ? Color.gray.opacity(0.45)
                            : Color("WWFGreen").opacity(0.75)
                    ),
                    style: StrokeStyle(
                        lineWidth: 3,
                        dash: segmentCompleted ? [] : [8, 4]
                    )
                )
            }
        }
    }
}

// MARK: - Marker POI visitatore

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
            }
            Circle()
                .fill(
                    isCompleted ? Color.gray
                    : isCurrent ? Color.yellow
                    : Color("WWFGreen")
                )
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

// MARK: - Barra progresso

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                Rectangle()
                    .fill(Color("WWFGreen"))
                    .frame(width: geo.size.width * fraction)
                    .animation(.spring(), value: fraction)
            }
        }
    }
}

// MARK: - Banner completamento percorso

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
