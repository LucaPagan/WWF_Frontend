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
                    .stroke(Color.black, lineWidth: 2.5)
            }
            .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 12) {
                // Top row
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.localizedName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text(event.localizedDescription)
                        .font(.system(size: 15, weight: .regular))
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
                            .font(.system(size: 14, weight: .semibold))
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    // Tappe
                    HStack(spacing: 4) {
                        Image(systemName: "shoe.fill")
                            .font(.caption)
                            .foregroundColor(customEventCardBrown)
                        Text("\(event.trail?.steps.count) \(localizer.localizedString(for: "steps_label"))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.trailing, 12)
            .padding(.leading, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.trail?.localizedName). \(event.trail?.localizedDescription). \(difficultyLabel). \(event.trail?.estimatedMinutes ?? 60) minuti. \(event.trail?.steps.count) tappe.")
        .accessibilityHint("Tocca due volte per aprire i dettagli del percorso")
        .accessibilityAddTraits(.isButton)
    }
}
