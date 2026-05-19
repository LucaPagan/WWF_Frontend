//
//  EventDetailView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//  Redesigned — Maggio 2026
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Premium Hero Header (Bleeds into notch / status bar)
                    ZStack(alignment: .topLeading) {
                        // Sfondo scuro bosco mescolato con la tonalità della categoria
                        ZStack {
                            WWFDesign.Colors.forestDark
                            categoryColor.opacity(0.35)
                        }
                        .frame(height: 260)
                        
                        // Pattern organico — cerchi sfumati che evocano vegetazione
                        GeometryReader { geo in
                            ZStack {
                                Circle()
                                    .fill(WWFDesign.Colors.forestMid)
                                    .frame(width: 250, height: 250)
                                    .blur(radius: 60)
                                    .offset(x: geo.size.width * 0.5, y: -40)
                                    .opacity(0.65)

                                Circle()
                                    .fill(WWFDesign.Colors.forestLight)
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 40)
                                    .offset(x: geo.size.width * 0.7, y: 80)
                                    .opacity(0.3)
                            }
                        }
                        
                        // Foglia decorativa in alto a destra
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 140))
                            .foregroundColor(WWFDesign.Colors.leafGreen.opacity(0.06))
                            .rotationEffect(.degrees(-25))
                            .offset(x: UIScreen.main.bounds.width - 150, y: 30)
                        
                        // Contenuto testuale allineato in basso
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer()
                            
                            // Titolo dell'evento
                            Text(event.localizedName)
                                .font(Font.custom("Georgia", size: 26).weight(.bold))
                                .foregroundColor(Color(red: 0.941, green: 0.929, blue: 0.902)) // #f0ede6
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                            // Data e ora dell'evento
                            HStack(spacing: 12) {
                                Label(event.formattedDate, systemImage: "calendar")
                                    .font(WWFDesign.Typography.chipLabel)
                                    .foregroundColor(WWFDesign.Colors.leafLight)
                                Label(event.formattedTimeRange, systemImage: "clock")
                                    .font(WWFDesign.Typography.chipLabel)
                                    .foregroundColor(WWFDesign.Colors.leafLight)
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                        .frame(height: 260, alignment: .leading)
                        
                        // Top Row: Pulsante indietro e Categoria dell'evento sulla stessa riga
                        HStack(alignment: .center) {
                            // Pulsante indietro floating botanico
                            Button {
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(WWFDesign.Colors.forestMid.opacity(0.35))
                                        .background(.ultraThinMaterial)
                                        .overlay(
                                            Circle().stroke(WWFDesign.Colors.leafGreen.opacity(0.35), lineWidth: 0.5)
                                        )
                                        .clipShape(Circle())
                                    
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(WWFDesign.Colors.leafLight)
                                        .offset(x: -1)
                                }
                                .frame(width: 40, height: 40)
                            }
                            
                            Spacer()
                            
                            // Badge Categoria allineato a destra
                            HStack(spacing: 5) {
                                Image(systemName: event.category.icon)
                                    .font(.system(size: 10, weight: .bold))
                                Text(localizer.localizedString(for: "event_cat_" + event.category.rawValue))
                                    .font(WWFDesign.Typography.badge)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(categoryColor.opacity(0.75))
                            .clipShape(Capsule())
                        }
                        .padding(.top, 54)
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 260)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: WWFDesign.Radius.hero,
                            bottomTrailingRadius: WWFDesign.Radius.hero,
                            topTrailingRadius: 0
                        )
                    )

                    VStack(spacing: 16) {
                        
                        // MARK: Info rapide (Quick Stats Strip)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                EventInfoChip(icon: "person.2.fill", text: "\(localizer.localizedString(for: "max_label")) \(event.maxParticipants ?? 30)", color: .blue)
                                if event.price > 0 {
                                    EventInfoChip(icon: "eurosign.circle.fill", text: String(format: "%.2f €", event.price), color: .orange)
                                } else {
                                    EventInfoChip(icon: "eurosign.circle.fill", text: localizer.localizedString(for: "free_price"), color: WWFDesign.Colors.forestLight)
                                }
                                EventInfoChip(icon: "person.crop.circle.fill", text: localizer.localizedString(for: "audience_" + event.targetAudience.rawValue), color: .purple)
                                if let poi = event.eventPOI {
                                    EventInfoChip(icon: poi.type.icon, text: poi.localizedName, color: poi.type.color)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // MARK: Descrizione
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizer.localizedString(for: "description"))
                                .font(WWFDesign.Typography.sectionTitle)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                            
                            Text(event.localizedDescription)
                                .font(WWFDesign.Typography.trailName)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // MARK: Organizzazione
                        if !(event.organizerName?.isEmpty ?? true) || !(event.contactInfo?.isEmpty ?? true) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(localizer.localizedString(for: "organization"))
                                    .font(WWFDesign.Typography.sectionTitle)
                                    .foregroundColor(WWFDesign.Colors.forestDark)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    if let organizer = event.organizerName, !organizer.isEmpty {
                                        HStack(spacing: 10) {
                                            Image(systemName: "building.2.fill")
                                                .foregroundColor(.blue)
                                                .font(.subheadline)
                                            Text(organizer)
                                                .font(WWFDesign.Typography.trailName)
                                        }
                                    }
                                    if let contact = event.contactInfo, !contact.isEmpty {
                                        HStack(spacing: 10) {
                                            Image(systemName: "envelope.fill")
                                                .foregroundColor(WWFDesign.Colors.forestLight)
                                                .font(.subheadline)
                                            Text(contact)
                                                .font(WWFDesign.Typography.trailName)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // MARK: Requisiti
                        if let reqs = event.localizedRequirements, !reqs.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(localizer.localizedString(for: "what_to_bring"))
                                    .font(WWFDesign.Typography.sectionTitle)
                                    .foregroundColor(WWFDesign.Colors.forestDark)
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "backpack.fill")
                                        .foregroundColor(.orange)
                                        .font(.title3)
                                    Text(reqs)
                                        .font(WWFDesign.Typography.trailName)
                                        .foregroundColor(.secondary)
                                        .lineSpacing(3)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                                    .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .padding(.horizontal, 16)
                        }

                        // MARK: Percorso associato
                        if let trail = event.trail {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(localizer.localizedString(for: "how_to_reach_us"))
                                    .font(WWFDesign.Typography.sectionTitle)
                                    .foregroundColor(WWFDesign.Colors.forestDark)

                                TrailEventCard(trail: trail)
                            }
                            .padding(.horizontal, 16)
                        }

                        // MARK: Avviso offline
                        HStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .font(.title3)
                                .foregroundColor(WWFDesign.Colors.forestLight)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(localizer.localizedString(for: "offline_mode"))
                                    .font(WWFDesign.Typography.trailName)
                                    .fontWeight(.semibold)
                                Text(localizer.localizedString(for: "offline_trail_desc"))
                                    .font(WWFDesign.Typography.trailDesc)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WWFDesign.Colors.forestMid.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                                .stroke(WWFDesign.Colors.forestMid.opacity(0.12), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                        .padding(.horizontal, 16)

                        // MARK: CTA Button
                        if let trail = event.trail {
                            Button {
                                startTrail = true
                            } label: {
                                Label(localizer.localizedString(for: "start_trail_event"), systemImage: "figure.hiking")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(WWFDesign.Colors.forestMid)
                                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                                    .shadow(color: WWFDesign.Colors.forestMid.opacity(0.25), radius: 6, x: 0, y: 3)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .fullScreenCover(isPresented: $startTrail) {
                                ActiveTrailView(trail: trail)
                            }
                        } else if let poi = event.eventPOI {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(WWFDesign.Colors.forestLight)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(localizer.localizedString(for: "place_label")): \(poi.localizedName)")
                                        .font(WWFDesign.Typography.trailName)
                                        .fontWeight(.semibold)
                                    Text(localizer.localizedString(for: "reach_marked_point"))
                                        .font(WWFDesign.Typography.trailDesc)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WWFDesign.Colors.forestLight.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                                    .stroke(WWFDesign.Colors.forestLight.opacity(0.15), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .padding(.horizontal, 16)
                        }

                    }
                    .padding(.vertical, 8)

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .toolbar(.hidden)
    }
}

// MARK: - Trail Event Card (preview del percorso)

struct TrailEventCard: View {
    let trail: Trail
    @ObservedObject private var localizer = LocalizationManager.shared

    var difficulty: TrailDifficulty {
        trail.difficulty ?? .easy
    }

    var badgeFill: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.easyFill
        case .medium: return WWFDesign.Colors.mediumFill
        case .hard:   return WWFDesign.Colors.hardFill
        }
    }

    var badgeText: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.easyText
        case .medium: return WWFDesign.Colors.mediumText
        case .hard:   return WWFDesign.Colors.hardText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "signpost.right.and.left.fill")
                    .foregroundColor(WWFDesign.Colors.forestMid)
                Text(trail.localizedName)
                    .font(WWFDesign.Typography.trailName)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            HStack(spacing: 14) {
                Text(localizer.localizedString(for: "difficulty_" + difficulty.rawValue))
                    .font(WWFDesign.Typography.badge)
                    .fontWeight(.bold)
                    .foregroundColor(badgeText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeFill)
                    .clipShape(Capsule())
                
                Label("\(trail.estimatedMinutes ?? 60) min", systemImage: "clock")
                    .font(WWFDesign.Typography.metaLabel)
                    .foregroundColor(.secondary)
                Label("\(trail.steps.count) \(localizer.localizedString(for: "steps_label"))", systemImage: "mappin.and.ellipse")
                    .font(WWFDesign.Typography.metaLabel)
                    .foregroundColor(.secondary)
            }

            Text(trail.localizedDescription)
                .font(WWFDesign.Typography.trailDesc)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                .stroke(WWFDesign.Colors.forestLight.opacity(0.15), lineWidth: 1)
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
                .font(WWFDesign.Typography.metaLabel)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}
