//
//  AlertBanner.swift
//  WWFChallenge7
//
//  Universal accessible alert component following WCAG 1.4.1:
//  Information is NEVER conveyed by color alone — always color + icon + text label.
//  Haptic feedback for danger alerts. Full VoiceOver support.
//

import SwiftUI

// MARK: - Alert Type

enum POIAlertType {
    case warning, danger, info

    var color: Color {
        switch self {
        case .warning: return Color.orange
        case .danger:  return Color.red
        case .info:    return Color.blue
        }
    }

    var icon: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .danger:  return "xmark.octagon.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .warning: return "Attenzione"
        case .danger:  return "Pericolo"
        case .info:    return "Informazione"
        }
    }
}

// MARK: - Alert Banner View

struct AlertBanner: View {
    let type: POIAlertType
    let message: String
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences

    var body: some View {
        HStack(spacing: 12) {
            // Icon — never rely on color alone
            Image(systemName: type.icon)
                .font(.title2)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                // Text label — always present
                Text(type.label)
                    .font(.headline)
                Text(message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .foregroundColor(type.color)
        .padding()
        .background(type.color.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(width: 4)
                .foregroundColor(type.color),
            alignment: .leading
        )
        .cornerRadius(8)
        .onAppear {
            // Haptic feedback for danger alerts
            if type == .danger {
                accessibilityPreferences.triggerNotificationHaptic(type: .warning)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.label): \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}
