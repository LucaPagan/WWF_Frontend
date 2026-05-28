//
//  DashboardView.swift
//  WWFChallenge7
//
//  Redesigned — Maggio 2026
//

import SwiftUI
import SwiftData

// MARK: - Design System

enum WWFDesign {
    // Palette principale — bosco vulcanico
    enum Colors {
        // Verde foresta (hero, accenti primari)
        static let forestDark     = Color(red: 0.102, green: 0.200, blue: 0.126) // #1a3320
        static let forestMid      = Color(red: 0.176, green: 0.353, blue: 0.227) // #2d5a3a
        static let forestLight    = Color(red: 0.388, green: 0.600, blue: 0.133) // #639922

        // Accenti naturali
        static let leafGreen      = Color(red: 0.478, green: 0.714, blue: 0.282) // #7ab648
        static let leafLight      = Color(red: 0.659, green: 0.847, blue: 0.478) // #a8d87a

        // Badge difficoltà
        static let easyFill       = Color(red: 0.918, green: 0.953, blue: 0.871) // #eaf3de
        static let easyText       = Color(red: 0.231, green: 0.427, blue: 0.067) // #3b6d11
        static let mediumFill     = Color(red: 0.980, green: 0.933, blue: 0.851) // #faeeda
        static let mediumText     = Color(red: 0.522, green: 0.310, blue: 0.043) // #854f0b
        static let hardFill       = Color(red: 0.988, green: 0.922, blue: 0.922) // #fcebeb
        static let hardText       = Color(red: 0.639, green: 0.176, blue: 0.176) // #a32d2d

        // Warning
        static let warningFill    = Color(red: 0.980, green: 0.933, blue: 0.851)
        static let warningBorder  = Color(red: 0.980, green: 0.780, blue: 0.459)
        static let warningText    = Color(red: 0.388, green: 0.220, blue: 0.024) // #633806
        static let warningBody    = Color(red: 0.522, green: 0.310, blue: 0.043)
    }

    enum Typography {
        static let heroTitle      = Font.custom("Georgia", size: 28, relativeTo: .title)
        static let heroSubtitle   = Font.system(.footnote).weight(.light)
        static let sectionTitle   = Font.custom("Georgia", size: 19, relativeTo: .headline)
        static let trailName      = Font.system(.subheadline).weight(.medium)
        static let trailDesc      = Font.system(.caption).weight(.light)
        static let chipLabel      = Font.system(.caption).weight(.medium)
        static let metaLabel      = Font.system(.caption2)
        static let badge          = Font.system(.caption2).weight(.medium)
    }

    enum Radius {
        static let card: CGFloat   = 16
        static let hero: CGFloat   = 20
        static let chip: CGFloat   = 20
        static let badge: CGFloat  = 10
        static let warning: CGFloat = 12
    }
}

// MARK: - Main Dashboard

struct DashboardView: View {
    @Query(filter: #Predicate<Trail> { $0.isActive == true })
    private var trails: [Trail]

    @State private var selectedTrail: Trail? = nil
    @State private var trailToStart: Trail? = nil
    @State private var visibleTrailId: UUID? = nil
    @State private var is3DMap: Bool = false
    @ObservedObject private var localizer = LocalizationManager.shared
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences
    @EnvironmentObject var syncManager: SyncManager

    private var displayedTrails: [Trail] {
        var byName: [String: Trail] = [:]
        for trail in trails.sorted(by: trailSort) {
            let key = trail.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if byName[key] == nil {
                byName[key] = trail
            }
        }
        return byName.values.sorted(by: trailSort)
    }

    private var currentTrail: Trail {
        if let id = visibleTrailId, let trail = displayedTrails.first(where: { $0.id == id }) {
            return trail
        }
        return displayedTrails.first ?? Trail(name: "", description: "")
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background Map
                Group {
                    if is3DMap {
                        Visitor3DMapView(
                            trail: currentTrail,
                            completedPOIIds: [],
                            currentStepPOIId: nil,
                            currentNormalizedPosition: .zero,
                            navigationState: .atStart,
                            mapType: .realistic
                        )
                        .accessibilityLabel("Mappa 3D dell'Oasi degli Astroni")
                    } else {
                        VisitorMapView(
                            trail: currentTrail,
                            completedPOIIds: [],
                            currentStepPOIId: nil,
                            currentNormalizedPosition: .zero,
                            navigationState: .atStart,
                            isDashboard: true
                        )
                        .accessibilityLabel("Mappa 2D dell'Oasi degli Astroni")
                    }
                }
                .ignoresSafeArea()
                .animation(.easeInOut, value: is3DMap)
                .animation(.easeInOut, value: currentTrail.id)
                
                // Top Overlay — Organic blob fully containing the title
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        // Organic blob — wider profile to match redesign
                        HStack(alignment: .top) {
                            TopWavyShape()
                                .fill(WWFDesign.Colors.forestLight)
                                // CHANGED: wider (full width) to properly cover text
                                .frame(width: geo.size.width, height: 165)
                                .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 3)

                            Spacer()
                        }
                        .ignoresSafeArea(edges: .top)

                        // Title text
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Oasi degli Astroni")
                                // CHANGED: .bold instead of .heavy — matches image 2 weight
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(localizer.localizedString(for: "explore"))
                                // CHANGED: slightly lighter subtitle
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.88))
                        }
                        .padding(.top, 58)
                        .padding(.leading, 22)

                        // 3D toggle button — top right
                        HStack {
                            Spacer()
                            Button(action: {
                                is3DMap.toggle()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 48, height: 48)
                                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                                    Text(is3DMap ? "2D" : "3D")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(.top, 58)
                            .padding(.trailing, 20)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Bottom Overlay: Trail Cards
                if !displayedTrails.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(displayedTrails) { trail in
                                AstroniTrailCard(trail: trail)
                                    .containerRelativeFrame(.horizontal, count: 1, spacing: 16)
                                    .onTapGesture {
                                        selectedTrail = trail
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $visibleTrailId)
                    .safeAreaPadding(.horizontal, 24)
                    .padding(.bottom, 120)
                    .onAppear {
                        if visibleTrailId == nil {
                            visibleTrailId = displayedTrails.first?.id
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedTrail) { trail in
                DownloadSelectionView(trail: trail) {
                    selectedTrail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        trailToStart = trail
                    }
                }
            }
            .fullScreenCover(item: $trailToStart) { trail in
                ActiveTrailView(trail: trail)
            }
            .task {
                await syncManager.pullLatestData()
            }
        }
    }

    private func trailSort(_ lhs: Trail, _ rhs: Trail) -> Bool {
        if lhs.needsSync != rhs.needsSync {
            return rhs.needsSync
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

// MARK: - Trail Card

struct AstroniTrailCard: View {
    let trail: Trail
    var interactive: Bool = true
    @ObservedObject private var localizer = LocalizationManager.shared

    private var difficulty: TrailDifficulty { trail.difficulty ?? .easy }

    private var accentColor: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.forestLight
        case .medium: return Color(red: 0.729, green: 0.459, blue: 0.043) // ambra
        case .hard:   return Color(red: 0.886, green: 0.294, blue: 0.290) // rosso
        }
    }

    private var badgeFill: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.easyFill
        case .medium: return WWFDesign.Colors.mediumFill
        case .hard:   return WWFDesign.Colors.hardFill
        }
    }

    private var badgeText: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.easyText
        case .medium: return WWFDesign.Colors.mediumText
        case .hard:   return WWFDesign.Colors.hardText
        }
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
                    .fill(WWFDesign.Colors.forestLight)
                CardBlobShape()
                    .stroke(Color.black, lineWidth: 2.5)
            }
            .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 12) {
                // Top row
                VStack(alignment: .leading, spacing: 6) {
                    Text(trail.localizedName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text(trail.localizedDescription)
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
                    .foregroundColor(badgeText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeFill)
                    .clipShape(Capsule())
                    
                    // Durata
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.522, green: 0.310, blue: 0.043))
                        Text("\(trail.estimatedMinutes ?? 60) min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    // Tappe
                    HStack(spacing: 4) {
                        Image(systemName: "shoe.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.522, green: 0.310, blue: 0.043))
                        Text("\(trail.steps.count) \(localizer.localizedString(for: "steps_label"))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.trailing, 20)
            .padding(.leading, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trail.localizedName). \(trail.localizedDescription). \(difficultyLabel). \(trail.estimatedMinutes ?? 60) minuti. \(trail.steps.count) tappe.")
        .accessibilityHint(interactive ? "Tocca due volte per aprire i dettagli del percorso" : "")
        .accessibilityAddTraits(interactive ? .isButton : [])
    }
}

// MARK: - Previews

#Preview("Dashboard — con percorsi") {
    DashboardView()
        .modelContainer(for: [Trail.self, POI.self], inMemory: true)
}
