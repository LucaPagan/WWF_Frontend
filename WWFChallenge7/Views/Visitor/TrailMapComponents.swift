//
//  MapPlaceholderView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

// MARK: - Map Placeholder
// Replace MapPlaceholderView() with Image("astroni_map")
// once the asset is ready

struct MapPlaceholderView: View {
    var body: some View {
        Image("astroni_map")
            .resizable()
            .scaledToFill()
            .clipped()
    }
}

// MARK: - Trail Path Overlay on Map

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

                // The path segment is gray if it has already been traversed
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
                            : WWFStyle.Colors.green.opacity(0.75)
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

// MARK: - Visitor POI Marker

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
                    : WWFStyle.Colors.green
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

// MARK: - Progress Bar

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                Rectangle()
                    .fill(WWFStyle.Colors.green)
                    .frame(width: geo.size.width * fraction)
                    .animation(.spring(), value: fraction)
            }
        }
    }
}

// MARK: - Trail Completion Banner

struct CompletedBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(LocalizationManager.shared.localizedString(for: "trail_completed"))
                    .fontWeight(.bold)
                Text(LocalizationManager.shared.localizedString(for: "great_job"))
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
