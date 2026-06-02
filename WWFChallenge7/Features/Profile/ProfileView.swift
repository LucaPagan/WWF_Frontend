//
//  ProfileView.swift
//  WWFChallenge7
//
//  Visitor profile redesigned to match the organic Dashboard language.
//

import SwiftUI
import SwiftData

struct ProfileUnlock: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let detail: String

    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

private enum SpeciesFilter: String, CaseIterable, Identifiable {
    case fauna
    case flora
    case geology
    case habitat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fauna: return LocalizationManager.shared.localizedString(for: "species_filter_fauna")
        case .flora: return LocalizationManager.shared.localizedString(for: "species_filter_flora")
        case .geology: return LocalizationManager.shared.localizedString(for: "species_filter_geology")
        case .habitat: return LocalizationManager.shared.localizedString(for: "species_filter_habitat")
        }
    }

    var icon: String {
        switch self {
        case .fauna: return "pawprint.fill"
        case .flora: return "leaf.fill"
        case .geology: return "mountain.2.fill"
        case .habitat: return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .fauna: return WWFDesign.Colors.accentAmbra
        case .flora: return WWFDesign.Colors.leafGreen
        case .geology: return Color(red: 0.72, green: 0.43, blue: 0.24)
        case .habitat: return Color(red: 0.45, green: 0.76, blue: 0.86)
        }
    }
}

private struct ProfileLanguage: Identifiable {
    let id: String
    let title: String
    let flag: String

    static let supported = [
        ProfileLanguage(id: "it", title: "IT", flag: "🇮🇹"),
        ProfileLanguage(id: "en", title: "EN", flag: "🇬🇧"),
        ProfileLanguage(id: "de", title: "DE", flag: "🇩🇪"),
        ProfileLanguage(id: "fr", title: "FR", flag: "🇫🇷")
    ]
}

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accessibilityPreferences: AccessibilityPreferences
    @EnvironmentObject private var userSession: UserSession
    @ObservedObject private var localizer = LocalizationManager.shared

    @AppStorage("preferredLanguage") private var language = "it"
    @AppStorage("notificationsEnabled") private var notifications = true

    @Query(sort: \LocalGamificationLevel.requiredXP) private var levels: [LocalGamificationLevel]
    @Query(sort: \LocalBadge.sortOrder) private var badges: [LocalBadge]
    @Query(sort: \LocalSpecies.name) private var species: [LocalSpecies]
    @Query private var gamificationStats: [LocalUserGamificationStats]
    @Query private var userBadges: [LocalUserBadge]
    @Query private var userSpecies: [LocalUserSpecies]
    @Query private var trailProgresses: [LocalTrailProgress]
    @Query private var validationLogs: [LocalValidationLog]
    @Query(sort: \Trail.name) private var trails: [Trail]

    @State private var selectedSpeciesFilter: SpeciesFilter = .fauna
    @State private var selectedSpecies: LocalSpecies?
    @State private var showProfileSettings = false
    @State private var showAccessibilitySettings = false

    private let profileStroke: CGFloat = 1.6

    private var stats: LocalUserGamificationStats? {
        gamificationStats.first(where: { $0.deviceId == userSession.deviceId }) ?? gamificationStats.first
    }

    private var deviceBadges: [LocalUserBadge] {
        userBadges.filter { $0.deviceId == userSession.deviceId }
    }

    private var deviceSpecies: [LocalUserSpecies] {
        userSpecies.filter { $0.deviceId == userSession.deviceId }
    }

    private var unlockedBadgeIds: Set<UUID> {
        Set(deviceBadges.map(\.badgeId))
    }

    private var unlockedSpeciesIds: Set<UUID> {
        Set(deviceSpecies.map(\.speciesId))
    }

    private var completedTrailProgresses: [LocalTrailProgress] {
        trailProgresses.filter { $0.status == .completed }
    }

    private var localPOIVisitedCount: Int {
        Set(trailProgresses.flatMap { $0.visits.map(\.poiId) }).count
    }

    private var localEventCompletedCount: Int {
        let accepted = validationLogs.filter { $0.eventType == "event_completed" && $0.status == .accepted }
        let identified = Set(accepted.compactMap(\.entityId))
        return max(identified.count, accepted.count)
    }

    private var displayedPOIVisitedCount: Int {
        max(stats?.poisVisitedCount ?? 0, localPOIVisitedCount)
    }

    private var displayedSpeciesCount: Int {
        max(stats?.speciesUnlockedCount ?? 0, unlockedSpeciesIds.count)
    }

    private var displayedEventsCount: Int {
        max(stats?.eventsCompletedCount ?? 0, localEventCompletedCount)
    }

    private var displayedBadgeCount: Int {
        max(stats?.badgesUnlockedCount ?? 0, unlockedBadgeIds.count)
    }

    private var activeLevels: [LocalGamificationLevel] {
        levels.filter(\.isActive)
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
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    WWFDesign.Colors.backgroundCream
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            headerSection
                            badgeCollection
                            biodiversityAlbum
                            statsSection
                            trailAchievements
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 154)
                        .padding(.bottom, 150)
                    }

                    profileTopOverlay(width: geo.size.width)
                        .ignoresSafeArea(edges: .top)
                        .zIndex(2)
                }
            }
            .sheet(item: $selectedSpecies) { selected in
                SpeciesDetailView(
                    species: selected,
                    isUnlocked: unlockedSpeciesIds.contains(selected.id),
                    easyReadMode: accessibilityPreferences.easyReadMode,
                    kidsMode: accessibilityPreferences.kidsMode
                )
            }
            .sheet(isPresented: $showProfileSettings) {
                ProfileSettingsSheet(
                    selectedLanguage: localizer.preferredLanguage,
                    notifications: $notifications,
                    onLanguageChange: setLanguage,
                    onAccessibility: {
                        showProfileSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showAccessibilitySettings = true
                        }
                    }
                )
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAccessibilitySettings) {
                AccessibilitySettingsView()
            }
            .onAppear {
                language = localizer.preferredLanguage
                refreshVisibleCounters()
            }
            .onChange(of: localizer.preferredLanguage) { _, newValue in
                language = newValue
            }
            .onChange(of: trailProgresses.count) { _, _ in refreshVisibleCounters() }
            .onChange(of: userBadges.count) { _, _ in refreshVisibleCounters() }
            .onChange(of: userSpecies.count) { _, _ in refreshVisibleCounters() }
            .onChange(of: validationLogs.count) { _, _ in refreshVisibleCounters() }
        }
    }

    private func profileTopOverlay(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top) {
                TopWavyShape()
                    .fill(WWFDesign.Colors.forestLight)
                    .frame(width: width, height: 165)
                    .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 3)

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 2) {
                Text(localizer.localizedString(for: "profile"))
                    .font(WWFDesign.Typography.titleHeroRounded)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.top, 58)
            .padding(.leading, 22)

            HStack {
                Spacer()
                Button {
                    showProfileSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(WWFDesign.Colors.forestDark)
                        .frame(width: 54, height: 54)
                        .background(
                            Circle()
                                .fill(WWFDesign.Colors.leafLight)
                                .shadow(color: WWFDesign.Colors.forestDark.opacity(0.25), radius: 10, x: 0, y: 5)
                        )
                        .overlay(Circle().stroke(WWFDesign.Colors.organicOutline.opacity(0.36), lineWidth: profileStroke))
                }
                .accessibilityLabel(localizer.localizedString(for: "settings"))
                .padding(.top, 56)
                .padding(.trailing, 22)
            }
        }
        .frame(height: 176)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ProfileAvatarView(level: currentLevel, stroke: profileStroke)

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentLevel?.localizedTitle ?? localizer.localizedString(for: "explorer"))
                        .font(WWFDesign.Typography.trailNameLarge)
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(userSession.isAnonymous ? localizer.localizedString(for: "visitor") : (userSession.username ?? userSession.email ?? localizer.localizedString(for: "visitor")))
                        .font(WWFDesign.Typography.bodyLargeRounded)
                        .foregroundColor(.black.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    XPProgressBar(
                        xp: stats?.xpTotal ?? 0,
                        nextXP: nextLevel?.requiredXP,
                        progress: levelProgress,
                        stroke: profileStroke
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 146, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(WWFDesign.Colors.cardCream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.34), lineWidth: 1.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .inset(by: 5)
                    .stroke(WWFDesign.Colors.organicInset.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.12), radius: 10, x: 0, y: 5)
        }
    }

    private var badgeCollection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("your_badges")

            if badges.isEmpty {
                EmptyOrganicState(text: localizer.localizedString(for: "no_badges_yet"), systemImage: "star.circle")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(badges.filter(\.isActive)) { badge in
                            BadgeTile(badge: badge, isUnlocked: unlockedBadgeIds.contains(badge.id), stroke: profileStroke)
                                .frame(width: 88)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var biodiversityAlbum: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("biodiversity_album")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SpeciesFilter.allCases) { filter in
                        SpeciesFilterChip(
                            filter: filter,
                            isSelected: selectedSpeciesFilter == filter,
                            stroke: profileStroke
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                selectedSpeciesFilter = filter
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            let filteredSpecies = species.filter {
                $0.isActive && $0.category.caseInsensitiveCompare(selectedSpeciesFilter.rawValue) == .orderedSame
            }

            if filteredSpecies.isEmpty {
                EmptyOrganicState(text: localizer.localizedString(for: "no_species_in_category"), systemImage: selectedSpeciesFilter.icon)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 14)], spacing: 14) {
                    ForEach(filteredSpecies) { item in
                        Button {
                            selectedSpecies = item
                        } label: {
                            SpeciesCard(species: item, isUnlocked: unlockedSpeciesIds.contains(item.id), stroke: profileStroke)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("your_statistics")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ProfileStatBlob(
                    value: displayedPOIVisitedCount,
                    label: localizer.localizedString(for: "pois_visited"),
                    icon: "safari.fill",
                    fill: WWFDesign.Colors.leafLight.opacity(0.86),
                    stroke: profileStroke,
                    variant: 0
                )
                ProfileStatBlob(
                    value: displayedSpeciesCount,
                    label: localizer.localizedString(for: "species_discovered"),
                    icon: "leaf.fill",
                    fill: WWFDesign.Colors.easyFill,
                    stroke: profileStroke,
                    variant: 1
                )
                ProfileStatBlob(
                    value: displayedEventsCount,
                    label: localizer.localizedString(for: "events_completed"),
                    icon: "calendar.badge.checkmark",
                    fill: WWFDesign.Colors.mediumFill,
                    stroke: profileStroke,
                    variant: 2
                )
                ProfileStatBlob(
                    value: displayedBadgeCount,
                    label: localizer.localizedString(for: "badges_unlocked"),
                    icon: "rosette",
                    fill: WWFDesign.Colors.hardFill,
                    stroke: profileStroke,
                    variant: 3
                )
            }
        }
    }

    private var trailAchievements: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("completed_trails")

            if completedTrailProgresses.isEmpty {
                EmptyProfileCard(text: localizer.localizedString(for: "no_trails_completed"), systemImage: "map")
            } else {
                ForEach(completedTrailProgresses) { progress in
                    if let trail = trails.first(where: { $0.id == progress.pathId }) {
                        AstroniTrailCard(trail: trail, interactive: false)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(localizer.localizedString(for: key))
            .font(WWFDesign.Typography.sectionLargeTitle)
            .foregroundColor(.black)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func setLanguage(_ code: String) {
        guard language != code || localizer.preferredLanguage != code else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            language = code
            localizer.setLanguage(code)
        }
    }

    private func refreshVisibleCounters() {
        let stats = ensureStats()
        stats.poisVisitedCount = displayedPOIVisitedCount
        stats.speciesUnlockedCount = displayedSpeciesCount
        stats.badgesUnlockedCount = displayedBadgeCount
        stats.trailsCompletedCount = max(stats.trailsCompletedCount, completedTrailProgresses.count)
        stats.eventsCompletedCount = displayedEventsCount
        stats.updatedAt = Date()
        try? modelContext.save()
    }

    private func ensureStats() -> LocalUserGamificationStats {
        if let stats {
            return stats
        }
        let created = LocalUserGamificationStats(deviceId: userSession.deviceId)
        modelContext.insert(created)
        return created
    }
}

private struct ProfileAvatarView: View {
    let level: LocalGamificationLevel?
    let stroke: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(WWFDesign.Colors.easyFill)
                .frame(width: 86, height: 86)
                .overlay(Circle().stroke(WWFDesign.Colors.organicOutline.opacity(0.42), lineWidth: stroke))

            if let url = level?.resolvedImageURL {
                RemoteArtwork(url: url, fallbackSystemImage: level?.iconName ?? "person.fill", contentMode: .fill)
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
            } else {
                Image(systemName: level?.iconName ?? "person.crop.circle.fill")
                    .font(.system(size: 50, weight: .semibold, design: .rounded))
                    .foregroundColor(WWFDesign.Colors.forestMid)
            }
        }
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
    }
}

private struct ProfileSettingsSheet: View {
    let selectedLanguage: String
    @Binding var notifications: Bool
    let onLanguageChange: (String) -> Void
    let onAccessibility: () -> Void
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(localizer.localizedString(for: "settings"))
                .font(WWFDesign.Typography.sectionLargeTitle)
                .foregroundColor(.black)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localizer.localizedString(for: "language"))
                        .font(WWFDesign.Typography.titleRounded)
                        .foregroundColor(.black)

                    HStack(spacing: 10) {
                        ForEach(ProfileLanguage.supported) { option in
                            LanguageChip(
                                option: option,
                                isSelected: selectedLanguage == option.id,
                                stroke: 1.6
                            ) {
                                onLanguageChange(option.id)
                            }
                        }
                    }
                }

                Toggle(isOn: $notifications) {
                    Label(localizer.localizedString(for: "notifications"), systemImage: "bell.fill")
                        .font(WWFDesign.Typography.bodyLargeRounded.weight(.semibold))
                        .foregroundColor(.black)
                }
                .tint(WWFDesign.Colors.forestLight)

                Button(action: onAccessibility) {
                    HStack {
                        Label(localizer.localizedString(for: "accessibility"), systemImage: "accessibility")
                            .font(WWFDesign.Typography.bodyLargeRounded.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(WWFDesign.Typography.caption.weight(.bold))
                    }
                    .foregroundColor(WWFDesign.Colors.forestDark)
                    .padding(.vertical, 4)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(WWFDesign.Colors.cardCream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.30), lineWidth: 1.3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .inset(by: 5)
                    .stroke(WWFDesign.Colors.organicInset.opacity(0.70), lineWidth: 1)
            )
            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.10), radius: 10, x: 0, y: 4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(WWFDesign.Colors.backgroundCream)
    }
}

private struct XPProgressBar: View {
    let xp: Int
    let nextXP: Int?
    let progress: Double
    let stroke: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WWFDesign.Colors.leafLight.opacity(0.55))
                    .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.40), lineWidth: stroke))

                Capsule()
                    .fill(WWFDesign.Colors.forestLight)
                    .frame(width: max(22, proxy.size.width * CGFloat(progress)))

                Text(nextXP.map { "\(xp) / \($0) XP" } ?? "\(xp) XP")
                    .font(WWFDesign.Typography.bodyLargeRounded.weight(.bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 30)
        .accessibilityLabel("XP \(xp)")
    }
}

private struct BadgeTile: View {
    let badge: LocalBadge
    let isUnlocked: Bool
    let stroke: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? rarityColor.opacity(0.92) : Color.gray.opacity(0.22))
                    .frame(width: 74, height: 74)
                    .overlay(
                        Circle()
                            .stroke(WWFDesign.Colors.organicOutline.opacity(isUnlocked ? 0.42 : 0.20), lineWidth: isUnlocked ? stroke : 1)
                    )

                if isUnlocked {
                    if let url = badge.resolvedImageURL {
                        RemoteArtwork(url: url, fallbackSystemImage: badge.iconName ?? "star.fill", contentMode: .fit)
                            .frame(width: 62, height: 62)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: badge.safeIconName)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(WWFDesign.Colors.forestDark)
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }

            Text(isUnlocked ? badge.localizedName : (badge.localizedUnlockHint ?? badge.localizedName))
                .font(WWFDesign.Typography.chipLabel)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.76)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var rarityColor: Color {
        switch badge.rarity.lowercased() {
        case "rare": return WWFDesign.Colors.leafLight
        case "epic": return Color(red: 0.75, green: 0.56, blue: 0.95)
        case "legendary": return WWFDesign.Colors.mediumFill
        default: return WWFDesign.Colors.warningFill
        }
    }
}

private struct SpeciesFilterChip: View {
    let filter: SpeciesFilter
    let isSelected: Bool
    let stroke: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(filter.title)
                    .font(WWFDesign.Typography.bodyLargeRounded.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Capsule().fill(isSelected ? filter.color : filter.color.opacity(0.32)))
            .overlay(
                Capsule()
                    .stroke(WWFDesign.Colors.organicOutline.opacity(isSelected ? 0.46 : 0.22), lineWidth: isSelected ? stroke : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SpeciesCard: View {
    let species: LocalSpecies
    let isUnlocked: Bool
    let stroke: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ProfileBlobShape(variant: abs(species.name.hashValue) % 4)
                    .fill(isUnlocked ? speciesFill : Color.gray.opacity(0.18))
                    .frame(height: 104)
                    .overlay(
                        ProfileBlobShape(variant: abs(species.name.hashValue) % 4)
                            .stroke(WWFDesign.Colors.organicOutline.opacity(isUnlocked ? 0.44 : 0.22), lineWidth: isUnlocked ? stroke : 1)
                    )

                if isUnlocked, let url = species.resolvedImageURL {
                    RemoteArtwork(url: url, fallbackSystemImage: species.iconName ?? "leaf.fill", contentMode: .fit)
                        .frame(width: 82, height: 82)
                } else {
                    Image(systemName: isUnlocked ? (species.iconName ?? "leaf.fill") : "questionmark")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(isUnlocked ? WWFDesign.Colors.forestDark : .gray)
                }
            }

            Text(isUnlocked ? species.localizedName : LocalizationManager.shared.localizedString(for: "species_locked"))
                .font(WWFDesign.Typography.chipLabel.weight(.bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
        }
        .padding(10)
        .frame(minHeight: 166)
        .background(WWFDesign.Colors.cardCream)
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.largeCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.largeCard, style: .continuous)
                .stroke(WWFDesign.Colors.organicOutline.opacity(0.26), lineWidth: 1.1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.largeCard - 3, style: .continuous)
                .inset(by: 4)
                .stroke(WWFDesign.Colors.organicInset.opacity(0.62), lineWidth: 0.9)
        )
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 7, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    private var speciesFill: Color {
        switch species.category.lowercased() {
        case "fauna": return WWFDesign.Colors.accentAmbra.opacity(0.78)
        case "flora": return WWFDesign.Colors.leafGreen.opacity(0.82)
        case "geology": return Color(red: 0.72, green: 0.43, blue: 0.24).opacity(0.78)
        case "habitat": return Color(red: 0.45, green: 0.76, blue: 0.86).opacity(0.78)
        default: return WWFDesign.Colors.easyFill
        }
    }
}

private struct ProfileStatBlob: View {
    let value: Int
    let label: String
    let icon: String
    let fill: Color
    let stroke: CGFloat
    let variant: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WWFDesign.Colors.forestDark)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.52)))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(WWFDesign.Typography.trailNameLarge)
                    .foregroundColor(.black)
                Text(label)
                    .font(WWFDesign.Typography.chipLabel)
                    .foregroundColor(.black.opacity(0.82))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 82)
        .background(ProfileBlobShape(variant: variant).fill(fill))
        .overlay(ProfileBlobShape(variant: variant).stroke(WWFDesign.Colors.organicOutline.opacity(0.34), lineWidth: 1.35))
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 5, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

private struct LanguageChip: View {
    let option: ProfileLanguage
    let isSelected: Bool
    let stroke: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(option.flag)
                    .font(.system(size: 18))
                Text(option.title)
                    .font(WWFDesign.Typography.badge.weight(.bold))
                    .foregroundColor(isSelected ? .white : .black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(isSelected ? WWFDesign.Colors.forestMid : WWFDesign.Colors.forestLight.opacity(0.18))
            )
            .overlay(
                Capsule()
                    .stroke(WWFDesign.Colors.organicOutline.opacity(isSelected ? 0.44 : 0.22), lineWidth: isSelected ? stroke : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct EmptyOrganicState: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WWFDesign.Colors.forestMid)
            Text(text)
                .font(WWFDesign.Typography.bodyLargeRounded)
                .foregroundColor(.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(16)
        .background(ProfileBlobShape(variant: 3).fill(Color.white.opacity(0.9)))
        .overlay(ProfileBlobShape(variant: 3).stroke(WWFDesign.Colors.organicOutline.opacity(0.22), lineWidth: 1))
    }
}

private struct EmptyProfileCard: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(WWFDesign.Colors.forestMid)
                .frame(width: 44, height: 44)
                .background(Circle().fill(WWFDesign.Colors.easyFill))

            Text(text)
                .font(WWFDesign.Typography.bodyLargeRounded.weight(.semibold))
                .foregroundColor(.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WWFDesign.Colors.cardCream)
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.largeCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.largeCard, style: .continuous)
                .stroke(WWFDesign.Colors.organicOutline.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

private struct RemoteArtwork: View {
    let url: URL
    let fallbackSystemImage: String
    let contentMode: ContentMode

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            default:
                Image(systemName: fallbackSystemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(WWFDesign.Colors.forestDark)
                    .padding(8)
            }
        }
    }
}

private struct ProfileBlobShape: Shape {
    let variant: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        switch variant % 4 {
        case 0:
            path.move(to: CGPoint(x: w * 0.10, y: h * 0.05))
            path.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.09), control1: CGPoint(x: w * 0.32, y: -h * 0.02), control2: CGPoint(x: w * 0.72, y: h * 0.01))
            path.addCurve(to: CGPoint(x: w * 0.95, y: h * 0.82), control1: CGPoint(x: w * 1.02, y: h * 0.28), control2: CGPoint(x: w * 1.01, y: h * 0.63))
            path.addCurve(to: CGPoint(x: w * 0.14, y: h * 0.95), control1: CGPoint(x: w * 0.72, y: h * 1.03), control2: CGPoint(x: w * 0.34, y: h * 1.01))
            path.addCurve(to: CGPoint(x: w * 0.10, y: h * 0.05), control1: CGPoint(x: -w * 0.02, y: h * 0.76), control2: CGPoint(x: -w * 0.02, y: h * 0.22))
        case 1:
            path.move(to: CGPoint(x: w * 0.08, y: h * 0.14))
            path.addCurve(to: CGPoint(x: w * 0.86, y: h * 0.05), control1: CGPoint(x: w * 0.27, y: h * 0.00), control2: CGPoint(x: w * 0.65, y: -h * 0.02))
            path.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.72), control1: CGPoint(x: w * 1.02, y: h * 0.20), control2: CGPoint(x: w * 1.03, y: h * 0.52))
            path.addCurve(to: CGPoint(x: w * 0.24, y: h * 0.94), control1: CGPoint(x: w * 0.78, y: h * 0.98), control2: CGPoint(x: w * 0.45, y: h * 1.02))
            path.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.14), control1: CGPoint(x: w * 0.02, y: h * 0.86), control2: CGPoint(x: -w * 0.03, y: h * 0.36))
        case 2:
            path.move(to: CGPoint(x: w * 0.16, y: h * 0.04))
            path.addCurve(to: CGPoint(x: w * 0.95, y: h * 0.18), control1: CGPoint(x: w * 0.35, y: h * 0.11), control2: CGPoint(x: w * 0.78, y: -h * 0.05))
            path.addCurve(to: CGPoint(x: w * 0.84, y: h * 0.92), control1: CGPoint(x: w * 1.03, y: h * 0.38), control2: CGPoint(x: w * 1.01, y: h * 0.78))
            path.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.82), control1: CGPoint(x: w * 0.60, y: h * 1.06), control2: CGPoint(x: w * 0.23, y: h * 0.99))
            path.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.04), control1: CGPoint(x: -w * 0.02, y: h * 0.62), control2: CGPoint(x: -w * 0.01, y: h * 0.18))
        default:
            path.move(to: CGPoint(x: w * 0.07, y: h * 0.22))
            path.addCurve(to: CGPoint(x: w * 0.74, y: h * 0.05), control1: CGPoint(x: w * 0.21, y: h * 0.03), control2: CGPoint(x: w * 0.55, y: -h * 0.01))
            path.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.62), control1: CGPoint(x: w * 0.93, y: h * 0.11), control2: CGPoint(x: w * 1.04, y: h * 0.42))
            path.addCurve(to: CGPoint(x: w * 0.30, y: h * 0.96), control1: CGPoint(x: w * 0.84, y: h * 0.92), control2: CGPoint(x: w * 0.53, y: h * 1.04))
            path.addCurve(to: CGPoint(x: w * 0.07, y: h * 0.22), control1: CGPoint(x: w * 0.06, y: h * 0.88), control2: CGPoint(x: -w * 0.04, y: h * 0.48))
        }

        path.closeSubpath()
        return path
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
                    .overlay(Circle().stroke(WWFDesign.Colors.organicOutline.opacity(0.40), lineWidth: 1.6))
                Image(systemName: "star.fill")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
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
        .background(WWFDesign.Colors.backgroundCream.opacity(kidsMode ? 0.85 : 1))
    }
}

struct SpeciesDetailView: View {
    let species: LocalSpecies
    let isUnlocked: Bool
    let easyReadMode: Bool
    let kidsMode: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        ProfileBlobShape(variant: 0)
                            .fill(isUnlocked ? WWFDesign.Colors.easyFill : Color.gray.opacity(0.18))
                            .frame(height: 190)
                            .overlay(ProfileBlobShape(variant: 0).stroke(WWFDesign.Colors.organicOutline.opacity(0.36), lineWidth: 1.5))

                        if isUnlocked, let url = species.resolvedImageURL {
                            RemoteArtwork(url: url, fallbackSystemImage: species.iconName ?? "leaf.fill", contentMode: .fit)
                                .frame(width: 150, height: 150)
                        } else {
                            Image(systemName: isUnlocked ? (species.iconName ?? "leaf.fill") : "questionmark")
                                .font(.system(size: kidsMode ? 86 : 70, weight: .bold, design: .rounded))
                                .foregroundColor(isUnlocked ? WWFDesign.Colors.forestMid : .secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isUnlocked ? species.localizedName : localizer.localizedString(for: "species_locked"))
                            .font(WWFDesign.Typography.sectionLargeTitle)
                            .foregroundColor(.black)

                        if isUnlocked, let scientificName = species.scientificName {
                            Text(scientificName)
                                .font(WWFDesign.Typography.bodyLargeRounded.italic())
                                .foregroundColor(.black.opacity(0.68))
                        }

                        Text(isUnlocked ? adaptiveDescription : localizer.localizedString(for: "species_locked_hint"))
                            .font(easyReadMode ? WWFDesign.Typography.titleRounded : WWFDesign.Typography.bodyLargeRounded)
                            .foregroundColor(.black.opacity(0.76))
                            .lineSpacing(4)

                        if isUnlocked {
                            Label(species.rarity.capitalized, systemImage: "sparkle")
                                .font(WWFDesign.Typography.chipLabel.weight(.bold))
                                .foregroundColor(WWFDesign.Colors.forestMid)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(WWFDesign.Colors.leafLight.opacity(0.32)))
                        }
                    }
                    .padding(18)
                    .background(ProfileBlobShape(variant: 2).fill(WWFDesign.Colors.cardCream))
                    .overlay(ProfileBlobShape(variant: 2).stroke(WWFDesign.Colors.organicOutline.opacity(0.28), lineWidth: 1.2))
                }
                .padding(24)
            }
            .background(WWFDesign.Colors.backgroundCream)
            .navigationTitle(localizer.localizedString(for: "biodiversity_album"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.localizedString(for: "close")) { dismiss() }
                }
            }
        }
    }

    private var adaptiveDescription: String {
        if easyReadMode, let description = species.localizedDescriptionEasyRead, !description.isEmpty {
            return description
        }
        if kidsMode, let description = species.localizedDescriptionKids, !description.isEmpty {
            return description
        }
        return species.localizedDescription
    }
}

private extension LocalBadge {
    var localizedName: String {
        let manager = LocalizationManager.shared
        let title = manager.localizedField(table: "badges", recordId: id, fieldName: "title", fallback: name)
        let nameTranslation = manager.localizedField(table: "badges", recordId: id, fieldName: "name", fallback: title)
        return manager.localizedKnownContent(nameTranslation)
    }

    var localizedDescription: String? {
        guard let badgeDescription else { return nil }
        let translated = LocalizationManager.shared.localizedField(table: "badges", recordId: id, fieldName: "description", fallback: badgeDescription)
        return LocalizationManager.shared.localizedKnownContent(translated)
    }

    var localizedUnlockHint: String? {
        guard let unlockHint else { return nil }
        let translated = LocalizationManager.shared.localizedField(table: "badges", recordId: id, fieldName: "unlock_hint", fallback: unlockHint)
        return LocalizationManager.shared.localizedKnownContent(translated)
    }

    var resolvedImageURL: URL? {
        if let imageURL, let url = SupabaseConfig.shared.publicStorageURL(for: imageURL) {
            return url
        }
        if let iconName, let url = SupabaseConfig.shared.publicStorageURL(for: iconName), iconName.contains("/") || iconName.contains("://") {
            return url
        }
        return nil
    }

    var safeIconName: String {
        guard let iconName, !iconName.contains("://") else { return "star.fill" }
        return iconName
    }
}

private extension LocalSpecies {
    var localizedName: String {
        LocalizationManager.shared.localizedField(table: "species", recordId: id, fieldName: "name", fallback: name)
    }

    var localizedDescription: String {
        LocalizationManager.shared.localizedField(table: "species", recordId: id, fieldName: "description", fallback: speciesDescription)
    }

    var localizedDescriptionKids: String? {
        guard let descriptionKids, !descriptionKids.isEmpty else { return nil }
        return LocalizationManager.shared.localizedField(table: "species", recordId: id, fieldName: "description_kids", fallback: descriptionKids)
    }

    var localizedDescriptionEasyRead: String? {
        guard let descriptionEasyRead, !descriptionEasyRead.isEmpty else { return nil }
        return LocalizationManager.shared.localizedField(table: "species", recordId: id, fieldName: "description_easy_read", fallback: descriptionEasyRead)
    }

    var resolvedImageURL: URL? {
        guard let imageURL else { return nil }
        return SupabaseConfig.shared.publicStorageURL(for: imageURL)
    }
}

private extension LocalGamificationLevel {
    var localizedTitle: String {
        let translated = LocalizationManager.shared.localizedField(table: "gamification_levels", recordId: id, fieldName: "title", fallback: title)
        return LocalizationManager.shared.localizedKnownContent(translated)
    }

    var resolvedImageURL: URL? {
        guard let imageURL else { return nil }
        return SupabaseConfig.shared.publicStorageURL(for: imageURL)
    }
}
