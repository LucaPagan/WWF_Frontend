//
//  EventDetailView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//

import SwiftUI

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var startTrail = false
    @ObservedObject private var localizer = LocalizationManager.shared

    var categoryColor: Color {
        event.category.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Hero
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    colors: [categoryColor, categoryColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 220)

                        VStack(alignment: .leading, spacing: 8) {
                            // Badge categoria
                            HStack(spacing: 6) {
                                Image(systemName: event.category.icon)
                                    .font(.caption)
                                Text(localizer.localizedString(for: "event_cat_" + event.category.rawValue))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())

                            Text(event.localizedName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                Label(event.formattedDate, systemImage: "calendar")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                Label(event.formattedTimeRange, systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding()
                    }

                    // MARK: Info rapide
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            EventInfoChip(icon: "person.2.fill", text: "\(localizer.localizedString(for: "max_label")) \(event.maxParticipants ?? 30)", color: .blue)
                            if event.price > 0 {
                                EventInfoChip(icon: "eurosign.circle.fill", text: String(format: "%.2f €", event.price), color: .orange)
                            } else {
                                EventInfoChip(icon: "eurosign.circle.fill", text: localizer.localizedString(for: "free_price"), color: .green)
                            }
                            EventInfoChip(icon: "person.crop.circle.fill", text: localizer.localizedString(for: "audience_" + event.targetAudience.rawValue), color: .purple)
                            if let poi = event.eventPOI {
                                EventInfoChip(icon: poi.type.icon, text: poi.localizedName, color: poi.type.color)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: Descrizione
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizer.localizedString(for: "description"))
                            .font(.headline)
                        Text(event.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: Organizzazione
                    if !(event.organizerName?.isEmpty ?? true) || !(event.contactInfo?.isEmpty ?? true) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizer.localizedString(for: "organization"))
                                .font(.headline)
                            if let organizer = event.organizerName, !organizer.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)
                                    Text(organizer)
                                        .font(.subheadline)
                                }
                            }
                            if let contact = event.contactInfo, !contact.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.green)
                                    Text(contact)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: Requisiti
                    if let reqs = event.localizedRequirements, !reqs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localizer.localizedString(for: "what_to_bring"))
                                .font(.headline)
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "backpack.fill")
                                    .foregroundColor(.orange)
                                Text(reqs)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // MARK: Percorso associato
                    if let trail = event.trail {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(localizer.localizedString(for: "how_to_reach_us"))
                                .font(.headline)
                                .padding(.horizontal)

                            TrailEventCard(trail: trail)
                                .padding(.horizontal)
                        }
                    }

                    // MARK: Avviso offline
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizer.localizedString(for: "offline_mode"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(localizer.localizedString(for: "offline_trail_desc"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // MARK: CTA
                    if let trail = event.trail {
                        Button {
                            startTrail = true
                        } label: {
                            Label(localizer.localizedString(for: "start_trail_event"), systemImage: "figure.hiking")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(WWFStyle.Colors.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                        .fullScreenCover(isPresented: $startTrail) {
                            ActiveTrailView(trail: trail)
                        }
                    } else {
                        // Nessun percorso — mostra solo info sul luogo
                        if let poi = event.eventPOI {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(WWFStyle.Colors.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(localizer.localizedString(for: "place_label")): \(poi.localizedName)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(localizer.localizedString(for: "reach_marked_point"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(WWFStyle.Colors.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 32)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, Color.white.opacity(0.3))
                            .font(.title3)
                    }
                }
            }
        }
    }
}

// MARK: - Trail Event Card (preview del percorso)

struct TrailEventCard: View {
    let trail: Trail
    @ObservedObject private var localizer = LocalizationManager.shared

    var difficulty: TrailDifficulty {
        trail.difficulty ?? .easy
    }

    var difficultyColor: Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "signpost.right.and.left.fill")
                    .foregroundColor(WWFStyle.Colors.green)
                Text(trail.localizedName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            HStack(spacing: 14) {
                Label(localizer.localizedString(for: "difficulty_" + difficulty.rawValue), systemImage: difficulty.icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(difficultyColor)
                Label("\(trail.estimatedMinutes ?? 60) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(trail.steps.count) \(localizer.localizedString(for: "steps_label"))", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(trail.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(WWFStyle.Colors.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(WWFStyle.Colors.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Info Chip

struct EventInfoChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
