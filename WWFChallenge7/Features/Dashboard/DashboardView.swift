//
//  DashboardView.swift
//  WWFChallenge7
//
//  Redesigned — Maggio 2026
//

import SwiftUI
import SwiftData

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
                            Text(localizer.localizedString(for: "app_title"))
                                // CHANGED: .bold instead of .heavy — matches image 2 weight
                                .font(WWFDesign.Typography.titleHeroRounded)
                                .foregroundColor(.white)

                            Text(localizer.localizedString(for: "explore"))
                                // CHANGED: slightly lighter subtitle
                                .font(WWFDesign.Typography.bodyLargeRounded)
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
                    .onChange(of: displayedTrails.map(\.id)) { _, trailIds in
                        guard !trailIds.isEmpty else {
                            visibleTrailId = nil
                            return
                        }

                        if visibleTrailId == nil || !trailIds.contains(visibleTrailId!) {
                            visibleTrailId = trailIds.first
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
        case .medium: return WWFDesign.Colors.accentAmbra
        case .hard:   return WWFDesign.Colors.accentRosso
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
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.38), lineWidth: 1.2)
            }
            .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 12) {
                // Top row
                VStack(alignment: .leading, spacing: 6) {
                    Text(trail.localizedName)
                        .font(WWFDesign.Typography.trailNameLarge)
                        .foregroundColor(.black)
                    
                    Text(trail.localizedDescription)
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
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(WWFDesign.Colors.warningBody)
                        Text("\(trail.estimatedMinutes ?? 60) min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    // Tappe
                    HStack(spacing: 4) {
                        Image(systemName: "shoe.fill")
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(WWFDesign.Colors.warningBody)
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
        .background {
            ZStack(alignment: .topTrailing) {
                WWFDesign.Colors.cardCream
                OrganicBlobShape(variant: 2)
                    .fill(accentColor.opacity(0.10))
                    .frame(width: 120, height: 90)
                    .offset(x: 34, y: -22)
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(accentColor.opacity(0.82))
                    .padding(18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WWFDesign.Colors.organicInset.opacity(0.68), lineWidth: 1).padding(4))
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 8, x: 0, y: 3)
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
