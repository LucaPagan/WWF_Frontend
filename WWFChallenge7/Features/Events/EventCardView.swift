//
//  EventCardView.swift
//  WWFChallenge7
//
//  Created by Manuel Alejandro Cruz Valladares on 27/05/26.
//

import SwiftUI

struct EventCardView: View {
    
    let event: Event
    let isHighlighted: Bool
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var difficulty: TrailDifficulty {
        event.trail?.difficulty ?? .easy
    }

    var categoryColor: Color {
        event.category.color
    }
    
    private var difficultyLabel: String {
        localizer.localizedString(for: "difficulty_" + difficulty.rawValue)
    }

    var body: some View {
        // Main Card
        HStack(spacing: 0) {
            // Left Green Bar (Inside the card)
            ZStack {
                CardBlobShape()
                    .fill(categoryColor)
                CardBlobShape()
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.55), lineWidth: 1.4)
            }
            .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 12) {
                // Top row
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.localizedName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text(event.localizedDescription)
                        .font(WWFDesign.Typography.trailDescBody)
                        .foregroundColor(.black.opacity(0.8))
                        // CHANGED: lineLimit increased to 3 — prevents mid-word truncation ("ci...")
                        // matching the full description visible in image 2
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Meta row
                HStack(spacing: 16) {
                    // Badge difficoltà
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                        Text(difficultyLabel)
                            .font(WWFDesign.Typography.chipLabel.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .clipShape(Capsule())
                    
                    // Durata
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(customEventCardBrown)
                        Text("\(event.trail?.estimatedMinutes ?? 60) min")
                            .font(WWFDesign.Typography.chipLabel)
                            .foregroundColor(.black)
                    }
                    
                    // Tappe
                    HStack(spacing: 4) {
                        Image(systemName: "shoe.fill")
                            .font(.caption)
                            .foregroundColor(customEventCardBrown)
                        Text("\(event.trail?.steps.count ?? 0) \(localizer.localizedString(for: "steps_label"))")
                            .font(WWFDesign.Typography.chipLabel)
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.trailing, 12)
            .padding(.leading, 12)
        }
        .background {
            ZStack(alignment: .topTrailing) {
                WWFDesign.Colors.cardCream
                OrganicBlobShape(variant: isHighlighted ? 2 : 1)
                    .fill(categoryColor.opacity(isHighlighted ? 0.16 : 0.10))
                    .frame(width: 120, height: 90)
                    .offset(x: 34, y: -22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(WWFDesign.Colors.organicOutline.opacity(0.28), lineWidth: 1.2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WWFDesign.Colors.organicInset.opacity(0.72), lineWidth: 1)
                .padding(4)
        )
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.trail?.localizedName ?? event.localizedName). \(event.trail?.localizedDescription ?? event.localizedDescription). \(difficultyLabel). \(event.trail?.estimatedMinutes ?? 60) \(localizer.localizedString(for: "minutes_word")). \(event.trail?.steps.count ?? 0) \(localizer.localizedString(for: "steps_label")).")
        .accessibilityHint(localizer.localizedString(for: "open_trail_details_hint"))
        .accessibilityAddTraits(.isButton)
    }
}
