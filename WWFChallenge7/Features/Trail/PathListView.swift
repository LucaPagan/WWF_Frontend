//
//  PathListView.swift
//  WWFChallenge7
//
//  Accessible list alternative to the map view for trail navigation.
//  Auto-selected when VoiceOver is running. Each step shows direction hints,
//  distance, and estimated time in a sequential, screen-reader-friendly format.
//

import SwiftUI

struct PathListView: View {
    let trail: Trail
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(trail.sortedSteps.enumerated()), id: \.element.id) { index, step in
                    PathStepRow(step: step, stepNumber: index + 1, isLast: index == trail.sortedSteps.count - 1)
                }
            }
            .padding(.top, 120) // Spazio per i controlli in alto
            .padding(.bottom, 350) // Spazio per non far finire la lista sotto al modale in basso
        }
        .accessibilityLabel("Lista step del percorso \(trail.localizedName)")
    }
}

// MARK: - PathStepRow

struct PathStepRow: View {
    let step: TrailStep
    let stepNumber: Int
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Step number indicator
                ZStack {
                    Circle()
                        .fill(stepNumber == 1 ? WWFDesign.Colors.forestLight.opacity(0.15) : Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    Text("\(stepNumber)")
                        .font(WWFDesign.Typography.headline)
                        .foregroundColor(stepNumber == 1 ? WWFDesign.Colors.forestLight : .primary)
                }
                .padding(.top, 12)

                // Step content
                VStack(alignment: .leading, spacing: 8) {
                    if let poi = step.poi {
                        Text(poi.localizedName)
                            .font(WWFDesign.Typography.headline)

                        // POI type badge
                        HStack(spacing: 4) {
                            Image(systemName: poi.type.icon)
                                .font(WWFDesign.Typography.caption)
                            Text(poi.type.displayName)
                                .font(WWFDesign.Typography.caption)
                        }
                        .foregroundColor(poi.type.color)
                    }

                    // Direction hint
                    Text(step.instructions)
                        .font(WWFDesign.Typography.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Distance and time chips
                    HStack(spacing: 16) {
                        Label("\(step.distanceMeters)m", systemImage: "figure.walk")
                            .font(WWFDesign.Typography.subheadline)
                            .foregroundColor(.secondary)

                        Label("\(step.estimatedMinutes) min", systemImage: "clock")
                            .font(WWFDesign.Typography.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 12)

                Spacer()
            }
            .padding(.horizontal, 16)
            .background(
                Group {
                    if !isLast {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 2)
                            .padding(.leading, 16 + 21) // 16 padding + 22 (centro cerchio) - 1 (metà linea)
                            .padding(.top, 12 + 44) // Inizia esattamente sotto il cerchio
                            .padding(.bottom, -12) // Estende la linea nel padding del prossimo elemento
                    }
                }
                , alignment: .leading
            )

            if !isLast {
                Divider()
                    .padding(.leading, 76)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Step \(stepNumber): \(step.poi?.localizedName ?? ""). " +
            "\(step.instructions). " +
            "Distanza: \(step.distanceMeters) metri, circa \(step.estimatedMinutes) minuti."
        )
    }
}
