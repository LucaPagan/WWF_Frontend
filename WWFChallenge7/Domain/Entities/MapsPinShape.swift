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
    var iconColor: Color = WWFDesign.Colors.forestDark

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let circle = min(w * 0.86, h * 0.68)
            let medallion = circle * 0.58

            ZStack(alignment: .top) {
                UnifiedMapPinShape()
                    .fill(fillColor)
                    .overlay(
                        UnifiedMapPinShape()
                            .stroke(.white.opacity(0.54), lineWidth: max(1, w * 0.035))
                    )

                ZStack {
                    Circle()
                        .fill(WWFDesign.Colors.organicInset)
                        .frame(width: medallion, height: medallion)
                        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.10), radius: 1.5, x: 0, y: 1)

                    Image(systemName: iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: medallion * 0.52, height: medallion * 0.52)
                        .foregroundColor(iconColor)
                }
                .frame(width: circle, height: circle)
                .position(x: w / 2, y: circle * 0.52)

                Ellipse()
                    .fill(.white.opacity(0.20))
                    .frame(width: circle * 0.42, height: circle * 0.16)
                    .position(x: w * 0.38, y: circle * 0.22)
            }
        }
    }
}

private struct UnifiedMapPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let circleRadius = min(w * 0.43, h * 0.34)
        let cx = rect.midX
        let cy = rect.minY + circleRadius + h * 0.03
        let tip = CGPoint(x: cx, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: cx - circleRadius, y: cy))
        path.addCurve(to: CGPoint(x: cx, y: cy - circleRadius), control1: CGPoint(x: cx - circleRadius, y: cy - circleRadius * 0.56), control2: CGPoint(x: cx - circleRadius * 0.56, y: cy - circleRadius))
        path.addCurve(to: CGPoint(x: cx + circleRadius, y: cy), control1: CGPoint(x: cx + circleRadius * 0.56, y: cy - circleRadius), control2: CGPoint(x: cx + circleRadius, y: cy - circleRadius * 0.56))
        path.addCurve(to: CGPoint(x: cx + circleRadius * 0.58, y: cy + circleRadius * 0.78), control1: CGPoint(x: cx + circleRadius, y: cy + circleRadius * 0.36), control2: CGPoint(x: cx + circleRadius * 0.82, y: cy + circleRadius * 0.62))
        path.addCurve(to: tip, control1: CGPoint(x: cx + circleRadius * 0.42, y: h * 0.72), control2: CGPoint(x: cx + circleRadius * 0.16, y: h * 0.88))
        path.addCurve(to: CGPoint(x: cx - circleRadius * 0.58, y: cy + circleRadius * 0.78), control1: CGPoint(x: cx - circleRadius * 0.16, y: h * 0.88), control2: CGPoint(x: cx - circleRadius * 0.42, y: h * 0.72))
        path.addCurve(to: CGPoint(x: cx - circleRadius, y: cy), control1: CGPoint(x: cx - circleRadius * 0.82, y: cy + circleRadius * 0.62), control2: CGPoint(x: cx - circleRadius, y: cy + circleRadius * 0.36))
        path.closeSubpath()
        return path
    }
}


// MARK: - Apple Maps Style POI Marker

struct MapsPOIMarker: View {
    let poi: POI
    let isCompleted: Bool
    let isCurrent: Bool

    private var pinColor: Color {
        if isCompleted { return Color(UIColor.systemGray) }
        if isCurrent   { return WWFDesign.Colors.leafLight }
        return WWFDesign.Colors.forestLight
    }

    private var iconColor: Color {
        if isCompleted { return Color(UIColor.systemGray) }
        return WWFDesign.Colors.forestDark
    }

    private var iconName: String {
        isCompleted ? "checkmark" : poi.type.icon
    }

    var body: some View {
        ZStack(alignment: .top) {

            // Pulse ring (current step only)
            if isCurrent {
                Circle()
                    .fill(WWFDesign.Colors.leafLight.opacity(0.24))
                    .frame(width: 46, height: 46)
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
            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.28), radius: 5, x: 0, y: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(poi.localizedName), \(isCompleted ? "completato" : isCurrent ? "tappa corrente" : "da visitare")"
        )
    }
}
