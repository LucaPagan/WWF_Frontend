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

    var categoryColor: Color {
        Color(hex: event.category.color) ?? .green
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
                                Text(event.category.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())

                            Text(event.name)
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
                            EventInfoChip(icon: "person.2.fill", text: "Max \(event.maxParticipants)", color: .blue)
                            EventInfoChip(icon: "eurosign.circle.fill", text: event.price, color: event.price.lowercased() == "gratuito" ? .green : .orange)
                            EventInfoChip(icon: "person.crop.circle.fill", text: event.targetAudience, color: .purple)
                            if let poi = event.eventPOI {
                                EventInfoChip(icon: poi.type.icon, text: poi.name, color: Color(hex: poi.type.color) ?? .green)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: Descrizione
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descrizione")
                            .font(.headline)
                        Text(event.eventDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: Organizzazione
                    if !event.organizerName.isEmpty || !event.contactInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Organizzazione")
                                .font(.headline)
                            if !event.organizerName.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)
                                    Text(event.organizerName)
                                        .font(.subheadline)
                                }
                            }
                            if !event.contactInfo.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.green)
                                    Text(event.contactInfo)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: Requisiti
                    if !event.requirements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cosa portare")
                                .font(.headline)
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "backpack.fill")
                                    .foregroundColor(.orange)
                                Text(event.requirements)
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
                            Text("Come raggiungerci")
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
                            Text("Modalità offline")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("La navigazione verso l'evento funziona senza internet. Segui il percorso e scansiona i QR code.")
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
                            Label("Inizia percorso verso l'evento", systemImage: "figure.hiking")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("WWFGreen"))
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
                                    .foregroundColor(Color("WWFGreen"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Luogo: \(poi.name)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Raggiungi il punto segnalato sulla mappa dell'Oasi.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color("WWFGreen").opacity(0.08))
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

    var difficultyColor: Color {
        switch trail.difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "signpost.right.and.left.fill")
                    .foregroundColor(Color("WWFGreen"))
                Text(trail.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            HStack(spacing: 14) {
                Label(trail.difficulty.rawValue, systemImage: trail.difficulty.icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(difficultyColor)
                Label("\(trail.estimatedMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(trail.steps.count) tappe", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(trail.trailDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color("WWFGreen").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("WWFGreen").opacity(0.2), lineWidth: 1)
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
