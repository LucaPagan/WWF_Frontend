//
//  POINewStyle.swift
//  WWFChallenge7
//
//  Created by Eleonora Persico on 27/05/26.
//

import SwiftUI

// MARK: - Apple Maps Pin Shape (custom View)

struct MapsPinShape: View {
    var fillColor: Color = WWFDesign.Colors.forestLight
    var iconName: String = "mappin.circle.fill"
    var iconColor: Color = .white

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundColor(iconColor)
                .padding(6)
                .background(fillColor)
                .cornerRadius(36)

            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 8, height: 8)
                .foregroundColor(fillColor)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
                .padding(.bottom, 25)
        }
    }
}


// MARK: - Apple Maps Style POI Marker

struct MapsPOIMarker: View {
    let poi: POI
    let isCompleted: Bool
    let isCurrent: Bool

    private var pinColor: Color {
        if isCompleted { return Color(UIColor.systemGray) }
        if isCurrent   { return .yellow }
        return WWFDesign.Colors.forestLight
    }

    private var iconColor: Color {
        if isCurrent { return Color(red: 0.48, green: 0.36, blue: 0) }
        return .white
    }

    private var iconName: String {
        isCompleted ? "checkmark.circle.fill" : poi.type.icon
    }

    var body: some View {
        ZStack(alignment: .top) {

            // Pulse ring (current step only)
            if isCurrent {
                Circle()
                    .fill(Color.yellow.opacity(0.25))
                    .frame(width: 52, height: 52)
                    .offset(y: 2)
                    .scaleEffect(isCurrent ? 1 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: isCurrent
                    )
            }

            // Pin — now a plain View, no .fill() needed
            MapsPinShape(
                fillColor: pinColor,
                iconName: iconName,
                iconColor: iconColor
            )
            .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(poi.localizedName), \(isCompleted ? "completato" : isCurrent ? "tappa corrente" : "da visitare")"
        )
    }
}
