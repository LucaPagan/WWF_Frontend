//
//  EventDetailView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//  Redesigned — Maggio 2026
//

import SwiftUI

private struct HeroHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gamificationService: GamificationService
    @State private var startTrail = false
    @State private var showCompletionScanner = false
    @State private var showCompletionCodePrompt = false
    @State private var completionCode = ""
    @State private var completionMessage: String?
    @State private var showCompletionMessage = false
    @State private var heroHeaderHeight: CGFloat = 0
    @ObservedObject private var localizer = LocalizationManager.shared

    var categoryColor: Color {
        event.category.color
    }

    private var heroHeaderBackground: some View {
        ZStack {
            WWFDesign.Colors.forestDark
            categoryColor.opacity(0.35)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Premium Hero Header (Bleeds into notch / status bar)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
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
                                        .font(.headline)
                                        .foregroundColor(WWFDesign.Colors.leafLight)
                                        .offset(x: -1)
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                            }
                            .accessibilityLabel("Torna indietro")

                            Spacer()
                        }
                        .padding(.top, 54)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.localizedName)
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.941, green: 0.929, blue: 0.902))
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                            HStack(spacing: 12) {
                                EventInfoChip(icon: "calendar", text: event.formattedDate, color: WWFDesign.Colors.leafLight, textColor: .white)
                                EventInfoChip(icon: "clock", text: event.formattedTimeRange, color: WWFDesign.Colors.leafLight, textColor: .white)
                            }

                            HStack(spacing: 5) {
                                Image(systemName: event.category.icon)
                                    .font(.caption2.weight(.bold))
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
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: HeroHeaderHeightKey.self, value: geo.size.height)
                        }
                    )
                    .onPreferenceChange(HeroHeaderHeightKey.self) { heroHeaderHeight = $0 }
                    .background {
                        ZStack(alignment: .topTrailing) {
                            heroHeaderBackground

                            Circle()
                                .fill(WWFDesign.Colors.forestMid)
                                .frame(width: 250, height: 250)
                                .blur(radius: 60)
                                .offset(x: 60, y: -40)
                                .opacity(0.65)

                            Circle()
                                .fill(WWFDesign.Colors.forestLight)
                                .frame(width: 140, height: 140)
                                .blur(radius: 40)
                                .offset(x: 40, y: 60)
                                .opacity(0.3)

                            Image(systemName: "leaf.fill")
                                .font(.system(size: 120))
                                .foregroundColor(WWFDesign.Colors.leafGreen.opacity(0.06))
                                .rotationEffect(.degrees(-25))
                                .padding(.top, 20)
                                .padding(.trailing, 8)
                                .accessibilityHidden(true)
                        }
                        .ignoresSafeArea(edges: .top)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.hero))

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

                        if event.completionQrPayload != nil || event.completionNumericCode != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Completamento evento")
                                    .font(WWFDesign.Typography.sectionTitle)
                                    .foregroundColor(WWFDesign.Colors.forestDark)

                                HStack(spacing: 12) {
                                    if event.completionQrPayload != nil {
                                        Button {
                                            showCompletionScanner = true
                                        } label: {
                                            Label("Scansiona QR", systemImage: "qrcode.viewfinder")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(WWFDesign.Colors.forestMid)
                                                .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                                        }
                                    }

                                    if event.completionNumericCode != nil {
                                        Button {
                                            showCompletionCodePrompt = true
                                        } label: {
                                            Label("Codice", systemImage: "number")
                                                .font(.headline)
                                                .foregroundColor(WWFDesign.Colors.forestMid)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(WWFDesign.Colors.forestMid.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
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
            .scrollContentBackground(.hidden)
            .background(alignment: .top) {
                VStack(spacing: 0) {
                    if heroHeaderHeight > 0 {
                        heroHeaderBackground
                            .frame(height: heroHeaderHeight)
                    }
                    Color(.systemGroupedBackground)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCompletionScanner) {
            QRScannerView { payload in
                showCompletionScanner = false
                gamificationService.eventCompleted(event, validationMethod: "qr", payload: payload)
                completionMessage = "Completamento registrato."
                showCompletionMessage = true
            }
            .ignoresSafeArea()
        }
        .alert("Codice completamento", isPresented: $showCompletionCodePrompt) {
            TextField("Codice", text: $completionCode)
            Button("Conferma") {
                gamificationService.eventCompleted(event, validationMethod: "numeric_code", payload: completionCode)
                completionCode = ""
                completionMessage = "Completamento registrato."
                showCompletionMessage = true
            }
            Button(localizer.localizedString(for: "cancel"), role: .cancel) {
                completionCode = ""
            }
        }
        .alert("Evento", isPresented: $showCompletionMessage) {
            Button(localizer.localizedString(for: "ok_button"), role: .cancel) {}
        } message: {
            Text(completionMessage ?? "")
        }
    }
}

// MARK: - Trail Event Card (preview del percorso)

struct TrailEventCard: View {
    let trail: Trail
    @ObservedObject private var localizer = LocalizationManager.shared
    @EnvironmentObject var accessibilityPrefs: AccessibilityPreferences

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

            Text(trail.adaptiveDescription(kidsMode: accessibilityPrefs.kidsMode, easyReadMode: accessibilityPrefs.easyReadMode))
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
    var textColor: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(WWFDesign.Typography.metaLabel)
                .fontWeight(.medium)
                .foregroundColor(textColor ?? color)
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

#Preview {
    EventDetailView(event: Event(
        name: "Escursione al Cratere degli Astroni",
        description: "Un'escursione guidata all'interno del cratere vulcanico degli Astroni, patrimonio naturale del WWF.",
        category: .educational,
        date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
        startTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
        endTime: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date(),
        maxParticipants: 25,
        organizerName: "WWF Italia — Oasi Astroni",
        contactInfo: "oasi.astroni@wwf.it",
        requirements: "Scarpe da trekking, acqua (almeno 1L), protezione solare.",
        targetAudience: .families,
        price: 0
    ))
    .environmentObject(GamificationService())
    .environmentObject(AccessibilityPreferences())
}
