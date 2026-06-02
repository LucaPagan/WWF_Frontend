import os

content = """//
//  ProfileView.swift
//  WWFChallenge7
//
//  Redesigned — Maggio 2026
//

import Combine
import SwiftUI
import SwiftData

struct ProfileUnlock: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private enum SpeciesFilter: String, CaseIterable, Identifiable {
    case fauna
    case flora
    case habitat
    case geology

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fauna: return "Fauna"
        case .flora: return "Flora"
        case .habitat: return "Habitat"
        case .geology: return "Geologia"
        }
    }
    
    var icon: String {
        switch self {
        case .fauna: return "pawprint.fill"
        case .flora: return "leaf.fill"
        case .habitat: return "tree.fill"
        case .geology: return "mountain.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fauna: return WWFDesign.Colors.accentAmbra
        case .flora: return WWFDesign.Colors.leafGreen
        case .habitat: return WWFDesign.Colors.forestLight
        case .geology: return WWFDesign.Colors.accentRosso
        }
    }
}

struct ProfileView: View {
    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var accessibilityPreferences: AccessibilityPreferences
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var gamificationService: GamificationService
    @ObservedObject private var localizer = LocalizationManager.shared

    @AppStorage("preferredLanguage") private var language = "it"
    @AppStorage("notificationsEnabled") private var notifications = true

    @Query(sort: \\LocalGamificationLevel.requiredXP) private var levels: [LocalGamificationLevel]
    @Query(sort: \\LocalBadge.sortOrder) private var badges: [LocalBadge]
    @Query(sort: \\LocalSpecies.name) private var species: [LocalSpecies]
    @Query private var gamificationStats: [LocalUserGamificationStats]
    @Query private var userBadges: [LocalUserBadge]
    @Query private var userSpecies: [LocalUserSpecies]
    @Query private var trailProgresses: [LocalTrailProgress]
    @Query(sort: \\Trail.name) private var trails: [Trail]

    @State private var selectedSpeciesFilter: SpeciesFilter = .fauna
    @State private var selectedSpecies: LocalSpecies?
    @State private var showAccessibilitySettings = false

    private var stats: LocalUserGamificationStats? {
        gamificationStats.first(where: { $0.deviceId == userSession.deviceId }) ?? gamificationStats.first
    }

    private var unlockedBadgeIds: Set<UUID> {
        Set(userBadges.map(\\.badgeId))
    }

    private var unlockedSpeciesIds: Set<UUID> {
        Set(userSpecies.map(\\.speciesId))
    }

    private var activeLevels: [LocalGamificationLevel] {
        levels.filter(\\.isActive)
    }

    private var currentLevel: LocalGamificationLevel? {
        activeLevels.last(where: { (stats?.xpTotal ?? 0) >= $0.requiredXP })
    }

    private var nextLevel: LocalGamificationLevel? {
        activeLevels.first(where: { $0.requiredXP > (stats?.xpTotal ?? 0) })
    }

    private var levelProgress: Double {
        guard let current = currentLevel else { return 0 }
        guard let next = nextLevel else { return 1 }
        let span = max(1, next.requiredXP - current.requiredXP)
        return min(1, max(0, Double((stats?.xpTotal ?? 0) - current.requiredXP) / Double(span)))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()
                
                TopWavyShape()
                    .fill(WWFDesign.Colors.forestLight)
                    .frame(height: 280)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .ignoresSafeArea(edges: .top)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        headerSection
                        
                        statsSection
                        badgeCollection
                        biodiversityAlbum
                        trailAchievements
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
                }
            }
            .sheet(item: $selectedSpecies) { species in
                SpeciesDetailView(species: species, isUnlocked: unlockedSpeciesIds.contains(species.id), easyReadMode: accessibilityPreferences.easyReadMode, kidsMode: accessibilityPreferences.kidsMode)
            }
            .sheet(isPresented: $showAccessibilitySettings) {
                AccessibilitySettingsView()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text(localizer.localizedString(for: "profile"))
                    .font(WWFDesign.Typography.titleHeroRounded)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showAccessibilitySettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 16)
            
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 4)
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(WWFDesign.Colors.forestMid)
                        .frame(width: 70, height: 70)
                }
                
                // Info & XP
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentLevel?.title ?? localizer.localizedString(for: "explorer"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\\(stats?.xpTotal ?? 0) XP")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            if let next = nextLevel {
                                Text("Next: \\(next.requiredXP) XP")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        // XP Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.black.opacity(0.2))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: geo.size.width * CGFloat(levelProgress))
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
        }
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            // POI
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WWFDesign.Colors.leafGreen)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black, lineWidth: 2.5)
                
                VStack {
                    Text("\\(stats?.poisVisitedCount ?? 0)")
                        .font(.title.bold())
                    Text(localizer.localizedString(for: "pois_visited"))
                        .font(.caption)
                }
                .foregroundColor(.black)
            }
            .frame(height: 100)
            
            // Specie
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WWFDesign.Colors.accentAmbra)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black, lineWidth: 2.5)
                
                VStack {
                    Text("\\(unlockedSpeciesIds.count)")
                        .font(.title.bold())
                    Text(localizer.localizedString(for: "species_discovered"))
                        .font(.caption)
                }
                .foregroundColor(.black)
            }
            .frame(height: 100)
        }
    }
    
    // MARK: - Badges
    
    private var badgeCollection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizer.localizedString(for: "your_badges"))
                .font(.title2.bold())
            
            if badges.isEmpty {
                Text(localizer.localizedString(for: "no_badges_yet"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(badges) { badge in
                            BadgeTile(badge: badge, isUnlocked: unlockedBadgeIds.contains(badge.id))
                                .frame(width: 80)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Biodiversita
    
    private var biodiversityAlbum: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizer.localizedString(for: "biodiversity_album"))
                .font(.title2.bold())
            
            // Grid Categorie
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(SpeciesFilter.allCases) { filter in
                    Button {
                        withAnimation { selectedSpeciesFilter = filter }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(selectedSpeciesFilter == filter ? filter.color : filter.color.opacity(0.3))
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.black, lineWidth: selectedSpeciesFilter == filter ? 2.5 : 1)
                            
                            VStack(spacing: 8) {
                                Image(systemName: filter.icon)
                                    .font(.title2)
                                Text(filter.title)
                                    .font(.headline)
                            }
                            .foregroundColor(.black)
                        }
                        .frame(height: 90)
                    }
                }
            }
            
            // Scroll Specie
            let filteredSpecies = species.filter { $0.category.lowercased() == selectedSpeciesFilter.rawValue.lowercased() }
            
            if filteredSpecies.isEmpty {
                Text(localizer.localizedString(for: "no_species_in_category"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(filteredSpecies) { sp in
                            Button {
                                selectedSpecies = sp
                            } label: {
                                SpeciesCard(species: sp, isUnlocked: unlockedSpeciesIds.contains(sp.id))
                                    .frame(width: 140, height: 180)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Percorsi
    
    private var trailAchievements: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizer.localizedString(for: "completed_trails"))
                .font(.title2.bold())
            
            let completed = trailProgresses.filter { $0.status == .completed }
            if completed.isEmpty {
                Text(localizer.localizedString(for: "no_trails_completed"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(completed) { progress in
                    if let trail = trails.first(where: { $0.id == progress.pathId }) {
                        AstroniTrailCard(trail: trail, interactive: false)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct BadgeTile: View {
    let badge: LocalBadge
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? WWFDesign.Colors.forestLight : Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                if isUnlocked {
                    Image(systemName: badge.iconName ?? "star.fill")
                        .font(.title)
                        .foregroundColor(WWFDesign.Colors.leafGreen)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                
                Circle()
                    .stroke(Color.black, lineWidth: isUnlocked ? 2 : 1)
            }
            
            Text(badge.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
                .lineLimit(2)
        }
    }
}

struct SpeciesCard: View {
    let species: LocalSpecies
    let isUnlocked: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16)
                .fill(isUnlocked ? WWFDesign.Colors.easyFill : Color.gray.opacity(0.2))
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: isUnlocked ? 2 : 1)
            
            VStack {
                Spacer()
                if isUnlocked {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundColor(WWFDesign.Colors.leafGreen)
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                Spacer()
                
                Text(species.name)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

struct UnlockCelebrationView: View {
    let unlock: ProfileUnlock
    let kidsMode: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(WWFDesign.Colors.accentAmbra)
                    .frame(width: 80, height: 80)
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .padding(.top, 24)
            
            Text(LocalizationManager.shared.localizedString(for: "congratulations"))
                .font(WWFDesign.Typography.titleHeroRounded)
                .foregroundColor(WWFDesign.Colors.forestDark)
            
            Text(unlock.title)
                .font(WWFDesign.Typography.headline)
            
            Text(unlock.detail)
                .font(WWFDesign.Typography.bodyLargeRounded)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

struct SpeciesDetailView: View {
    let species: LocalSpecies
    let isUnlocked: Bool
    let easyReadMode: Bool
    let kidsMode: Bool
    @Environment(\\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    let description = kidsMode ? (species.descriptionKids ?? species.speciesDescription) :
                        (easyReadMode ? (species.descriptionEasyRead ?? species.speciesDescription) : species.speciesDescription)
                        
                    ZStack {
                        Circle()
                            .fill(isUnlocked ? WWFDesign.Colors.leafGreen.opacity(0.2) : Color.gray.opacity(0.2))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: species.iconName ?? "leaf.fill")
                            .font(.system(size: kidsMode ? 82 : 66))
                            .foregroundColor(isUnlocked ? WWFDesign.Colors.forestMid : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isUnlocked ? species.name : "Specie da scoprire")
                            .font(.title2.weight(.bold))
                        if isUnlocked, let scientificName = species.scientificName {
                            Text(scientificName)
                                .font(.subheadline.italic())
                                .foregroundColor(.secondary)
                        }
                        Text(isUnlocked ? description : "Continua a esplorare l'Oasi per completare questa scheda dell'album.")
                            .font(easyReadMode ? .title3 : .body)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                        if isUnlocked {
                            Label(species.rarity.capitalized, systemImage: "sparkle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(WWFDesign.Colors.forestMid)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Biodiversità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
"""

with open('WWFChallenge7/Features/Profile/ProfileView.swift', 'w') as f:
    f.write(content)

print("ProfileView.swift rewritten successfully!")
