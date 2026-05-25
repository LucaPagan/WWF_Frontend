//
//  ProfileView.swift
//  WWFChallenge7
//

import Combine
import SwiftUI
import SwiftData

private enum BadgeFilter: String, CaseIterable, Identifiable {
    case exploration
    case nature
    case events
    case seasonal
    case kids
    case special

    var id: String { rawValue }
    var title: String {
        switch self {
        case .exploration: "Esplorazione"
        case .nature: "Natura"
        case .events: "Eventi"
        case .seasonal: "Stagionali"
        case .kids: "Kids"
        case .special: "Speciali"
        }
    }
}

private enum SpeciesFilter: String, CaseIterable, Identifiable {
    case fauna
    case flora
    case habitat
    case geology
    case conservation
    case history

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fauna: "Fauna"
        case .flora: "Flora"
        case .habitat: "Habitat"
        case .geology: "Geologia"
        case .conservation: "Conservazione"
        case .history: "Storia"
        }
    }
}

private struct ProfileUnlock: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct ProfileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var accessibilityPreferences: AccessibilityPreferences
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var gamificationService: GamificationService
    @ObservedObject private var localizer = LocalizationManager.shared

    @AppStorage("preferredLanguage") private var language = "it"
    @AppStorage("notificationsEnabled") private var notifications = true

    @Query(sort: \LocalGamificationLevel.requiredXP) private var levels: [LocalGamificationLevel]
    @Query(sort: \LocalBadge.sortOrder) private var badges: [LocalBadge]
    @Query(sort: \LocalSpecies.name) private var species: [LocalSpecies]
    @Query private var gamificationStats: [LocalUserGamificationStats]
    @Query private var userBadges: [LocalUserBadge]
    @Query private var userSpecies: [LocalUserSpecies]
    @Query private var eventLogs: [LocalGamificationEventLog]
    @Query private var validationLogs: [LocalValidationLog]
    @Query private var trailProgresses: [LocalTrailProgress]
    @Query(sort: \Trail.name) private var trails: [Trail]
    @Query(sort: \Event.date) private var events: [Event]

    @State private var selectedBadgeFilter: BadgeFilter = .exploration
    @State private var selectedSpeciesFilter: SpeciesFilter = .fauna
    @State private var selectedSpecies: LocalSpecies?
    @State private var unlockQueue: [ProfileUnlock] = []
    @State private var currentUnlock: ProfileUnlock?

    private var stats: LocalUserGamificationStats? {
        gamificationStats.first(where: { $0.deviceId == userSession.deviceId }) ?? gamificationStats.first
    }

    private var unlockedBadgeIds: Set<UUID> {
        Set(userBadges.map(\.badgeId))
    }

    private var unlockedSpeciesIds: Set<UUID> {
        Set(userSpecies.map(\.speciesId))
    }

    private var pendingSyncCount: Int {
        eventLogs.filter { $0.syncStatus == .pending }.count
        + userBadges.filter { $0.syncStatus == .pending }.count
        + userSpecies.filter { $0.syncStatus == .pending }.count
        + trailProgresses.filter(\.needsSync).count
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) {
                    header
                    progressOverview
                    levelProgressSection
                    badgeCollection
                    biodiversityAlbum
                    trailAchievements
                    eventRewards
                    recentUnlocks
                    settingsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(profileBackground.ignoresSafeArea())
            .navigationTitle("Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedSpecies) { species in
                SpeciesDetailView(species: species, isUnlocked: unlockedSpeciesIds.contains(species.id), easyReadMode: accessibilityPreferences.easyReadMode, kidsMode: accessibilityPreferences.kidsMode)
            }
            .sheet(item: $currentUnlock, onDismiss: showNextUnlockIfNeeded) { unlock in
                UnlockCelebrationView(unlock: unlock, kidsMode: accessibilityPreferences.kidsMode)
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: gamificationService.latestRewards) { _, rewards in
                enqueueUnlocks(rewards.map { ProfileUnlock(title: $0.title, detail: $0.detail) })
            }
            .onChange(of: gamificationService.latestLevelUp) { _, level in
                guard let level else { return }
                enqueueUnlocks([ProfileUnlock(title: "Nuovo livello", detail: level.title)])
            }
        }
    }

    private var spacing: CGFloat {
        accessibilityPreferences.easyReadMode || accessibilityPreferences.kidsMode ? 22 : 16
    }

    private var profileBackground: Color {
        accessibilityPreferences.easyReadMode ? Color(.systemBackground) : Color(.systemGroupedBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accessibilityPreferences.kidsMode ? WWFDesign.Colors.leafGreen.opacity(0.25) : WWFDesign.Colors.forestMid.opacity(0.16))
                    Image(systemName: "figure.hiking.circle.fill")
                        .font(.system(size: accessibilityPreferences.kidsMode ? 48 : 42))
                        .foregroundColor(WWFDesign.Colors.forestMid)
                }
                .frame(width: accessibilityPreferences.kidsMode ? 76 : 66, height: accessibilityPreferences.kidsMode ? 76 : 66)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(userSession.username ?? userSession.email ?? "Esploratore ospite")
                        .font(.title2.weight(.bold))
                        .foregroundColor(WWFDesign.Colors.forestDark)
                        .lineLimit(2)
                    Text(stats?.currentRank ?? currentLevel?.title ?? "Visitatore")
                        .font(.headline)
                        .foregroundColor(WWFDesign.Colors.forestMid)
                    if pendingSyncCount > 0 {
                        Label("\(pendingSyncCount) ricompense in attesa di sincronizzazione", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .accessibilityLabel("\(pendingSyncCount) progressi in attesa di sincronizzazione")
                    }
                }
                Spacer()
                levelIcon
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("XP")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(xpProgressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ProgressView(value: levelProgress)
                    .tint(WWFDesign.Colors.forestMid)
                    .accessibilityLabel("Progresso verso il prossimo livello")
                    .accessibilityValue(xpProgressText)
            }

            if userSession.isAnonymous {
                Text("Salva i tuoi progressi e porta con te la tua collezione")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(WWFDesign.Colors.forestMid)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WWFDesign.Colors.forestMid.opacity(accessibilityPreferences.easyReadMode ? 0.14 : 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(accessibilityPreferences.kidsMode ? 20 : 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .shadow(color: Color.black.opacity(accessibilityPreferences.easyReadMode ? 0 : 0.05), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profilo. \(stats?.currentRank ?? "Visitatore"). \(xpProgressText)")
    }

    private var levelIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: currentLevel?.iconName ?? "seal.fill")
                .font(.title2)
                .foregroundColor(.white)
            Text("L\(stats?.currentLevel ?? currentLevel?.levelNumber ?? 1)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        }
        .frame(width: 54, height: 54)
        .background(WWFDesign.Colors.forestMid)
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .accessibilityLabel("Livello \(stats?.currentLevel ?? currentLevel?.levelNumber ?? 1)")
    }

    private var xpProgressText: String {
        guard let nextLevel else {
            return "\(stats?.xpTotal ?? 0) XP"
        }
        return "\(stats?.xpTotal ?? 0) / \(nextLevel.requiredXP) XP"
    }

    private var progressOverview: some View {
        ProfileSection(title: accessibilityPreferences.kidsMode ? "La tua avventura" : "Panoramica") {
            LazyVGrid(columns: overviewColumns, spacing: 10) {
                OverviewCard(icon: "mappin.and.ellipse", value: "\(stats?.poisVisitedCount ?? uniqueVisitedPOICount)", label: "POI visitati", kidsMode: accessibilityPreferences.kidsMode)
                OverviewCard(icon: "figure.hiking", value: "\(stats?.trailsCompletedCount ?? completedTrailCount)", label: "Percorsi completati", kidsMode: accessibilityPreferences.kidsMode)
                OverviewCard(icon: "leaf.fill", value: "\(stats?.speciesUnlockedCount ?? unlockedSpeciesIds.count)", label: "Specie scoperte", kidsMode: accessibilityPreferences.kidsMode)
                OverviewCard(icon: "rosette", value: "\(stats?.badgesUnlockedCount ?? unlockedBadgeIds.count)", label: "Badge sbloccati", kidsMode: accessibilityPreferences.kidsMode)
                OverviewCard(icon: "calendar.badge.checkmark", value: "\(stats?.eventsCompletedCount ?? completedEventCount)", label: "Eventi completati", kidsMode: accessibilityPreferences.kidsMode)
            }
        }
    }

    private var overviewColumns: [GridItem] {
        [GridItem(.adaptive(minimum: accessibilityPreferences.easyReadMode || accessibilityPreferences.kidsMode ? 145 : 112), spacing: 10)]
    }

    private var levelProgressSection: some View {
        ProfileSection(title: "Livello") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentLevel?.title ?? "Visitatore")
                            .font(.headline)
                        Text(accessibilityPreferences.easyReadMode ? "Continua il percorso." : "Ogni visita aggiunge un pezzetto alla tua storia nell'Oasi.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let nextLevel {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Prossimo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(nextLevel.title)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                ProgressView(value: levelProgress)
                    .tint(WWFDesign.Colors.leafGreen)
                Text(nextLevelCopy)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .sectionCard()
        }
    }

    private var nextLevelCopy: String {
        guard let nextLevel else {
            return accessibilityPreferences.kidsMode ? "Hai riempito tutto l'album dei livelli disponibili." : "Hai raggiunto il livello più alto disponibile."
        }
        let missing = max(0, nextLevel.requiredXP - (stats?.xpTotal ?? 0))
        return accessibilityPreferences.easyReadMode ? "Mancano \(missing) XP." : "Mancano \(missing) XP per \(nextLevel.title)."
    }

    private var badgeCollection: some View {
        ProfileSection(title: accessibilityPreferences.kidsMode ? "Medaglie" : "Badge") {
            FilterChips(selection: $selectedBadgeFilter, values: BadgeFilter.allCases, title: \.title)
            LazyVGrid(columns: collectionColumns, spacing: 12) {
                ForEach(filteredBadges) { badge in
                    BadgeTile(
                        badge: badge,
                        isUnlocked: unlockedBadgeIds.contains(badge.id),
                        kidsMode: accessibilityPreferences.kidsMode,
                        easyReadMode: accessibilityPreferences.easyReadMode
                    )
                }
            }
        }
    }

    private var filteredBadges: [LocalBadge] {
        badges
            .filter { $0.isActive && normalizedBadgeCategory($0.category) == selectedBadgeFilter.rawValue }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func normalizedBadgeCategory(_ category: String) -> String {
        category == "loyalty" ? "special" : category
    }

    private var biodiversityAlbum: some View {
        ProfileSection(title: accessibilityPreferences.kidsMode ? "Album natura" : "Album biodiversità") {
            FilterChips(selection: $selectedSpeciesFilter, values: SpeciesFilter.allCases, title: \.title)
            LazyVGrid(columns: collectionColumns, spacing: 12) {
                ForEach(filteredSpecies) { item in
                    SpeciesTile(
                        species: item,
                        isUnlocked: unlockedSpeciesIds.contains(item.id),
                        kidsMode: accessibilityPreferences.kidsMode,
                        easyReadMode: accessibilityPreferences.easyReadMode
                    )
                    .onTapGesture {
                        selectedSpecies = item
                    }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var filteredSpecies: [LocalSpecies] {
        species.filter { $0.isActive && $0.category == selectedSpeciesFilter.rawValue }
    }

    private var collectionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: accessibilityPreferences.easyReadMode || accessibilityPreferences.kidsMode ? 150 : 126), spacing: 12)]
    }

    private var trailAchievements: some View {
        ProfileSection(title: "Percorsi") {
            VStack(spacing: 10) {
                ForEach(trails) { trail in
                    let progress = trailProgresses.first(where: { $0.pathId == trail.id })
                    TrailAchievementCard(trail: trail, progress: progress, easyReadMode: accessibilityPreferences.easyReadMode)
                }
            }
        }
    }

    private var eventRewards: some View {
        ProfileSection(title: "Eventi") {
            VStack(spacing: 10) {
                let completedIds = Set(eventLogs.filter { $0.triggerType == "event_completed" }.compactMap(\.entityId))
                let registeredIds = Set(eventLogs.filter { $0.triggerType == "event_registered" }.compactMap(\.entityId))
                ForEach(events.filter { completedIds.contains($0.id) || registeredIds.contains($0.id) || $0.isUpcoming }.prefix(5)) { event in
                    EventRewardCard(
                        event: event,
                        isCompleted: completedIds.contains(event.id),
                        isRegistered: registeredIds.contains(event.id),
                        hasCompletionValidation: event.completionQrPayload != nil || event.completionNumericCode != nil
                    )
                }
            }
        }
    }

    private var recentUnlocks: some View {
        ProfileSection(title: "Sbloccati di recente") {
            VStack(spacing: 10) {
                let badgeRows = userBadges.sorted { $0.unlockedAt > $1.unlockedAt }.prefix(3).map { badgeUnlock in
                    RecentUnlockRow(icon: "rosette", title: badgeName(for: badgeUnlock.badgeId), subtitle: "Badge", date: badgeUnlock.unlockedAt)
                }
                let speciesRows = userSpecies.sorted { $0.unlockedAt > $1.unlockedAt }.prefix(3).map { speciesUnlock in
                    RecentUnlockRow(icon: "leaf.fill", title: speciesName(for: speciesUnlock.speciesId), subtitle: "Specie", date: speciesUnlock.unlockedAt)
                }
                let levelRows = eventLogs.filter { $0.triggerType == "level_up" }.sorted { $0.occurredAt > $1.occurredAt }.prefix(2).map { log in
                    RecentUnlockRow(icon: "seal.fill", title: "Nuovo livello", subtitle: "Livello", date: log.occurredAt)
                }

                let rows = (badgeRows + speciesRows + levelRows).sorted { $0.date > $1.date }.prefix(5)
                if rows.isEmpty {
                    Text(accessibilityPreferences.kidsMode ? "Le prossime scoperte appariranno qui." : "Le nuove ricompense appariranno qui dopo le prossime visite.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sectionCard()
                } else {
                    ForEach(Array(rows)) { row in row }
                }
            }
        }
    }

    private var settingsSection: some View {
        ProfileSection(title: "Impostazioni") {
            VStack(spacing: 12) {
                Picker(localizer.localizedString(for: "language"), selection: Binding(
                    get: { language },
                    set: { newValue in
                        language = newValue
                        localizer.preferredLanguage = newValue
                        localizer.objectWillChange.send()
                    }
                )) {
                    Text("IT").tag("it")
                    Text("EN").tag("en")
                    Text("DE").tag("de")
                    Text("FR").tag("fr")
                }
                .pickerStyle(.segmented)

                Toggle(localizer.localizedString(for: "oasis_updates"), isOn: $notifications)
                    .tint(WWFDesign.Colors.forestMid)
                    .frame(minHeight: 44)

                NavigationLink {
                    AccessibilitySettingsView()
                } label: {
                    Label("Accessibilità", systemImage: "accessibility")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                        .foregroundColor(WWFDesign.Colors.forestMid)
                }

                LabeledContent(localizer.localizedString(for: "version"), value: "1.0.0")
                    .font(.subheadline)
                Link(destination: URL(string: "https://www.wwf.it")!) {
                    Label(localizer.localizedString(for: "wwf_website"), systemImage: "globe")
                        .foregroundColor(WWFDesign.Colors.forestMid)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
            }
            .sectionCard()
        }
    }

    private var uniqueVisitedPOICount: Int {
        Set(trailProgresses.flatMap { $0.visits.map(\.poiId) }).count
    }

    private var completedTrailCount: Int {
        trailProgresses.filter { $0.status == .completed }.count
    }

    private var completedEventCount: Int {
        eventLogs.filter { $0.triggerType == "event_completed" }.count
    }

    private func badgeName(for id: UUID) -> String {
        badges.first(where: { $0.id == id })?.name ?? "Badge"
    }

    private func speciesName(for id: UUID) -> String {
        species.first(where: { $0.id == id })?.name ?? "Specie"
    }

    private func enqueueUnlocks(_ unlocks: [ProfileUnlock]) {
        guard !unlocks.isEmpty else { return }
        unlockQueue.append(contentsOf: unlocks)
        if currentUnlock == nil {
            showNextUnlockIfNeeded()
        }
    }

    private func showNextUnlockIfNeeded() {
        guard currentUnlock == nil || !unlockQueue.isEmpty else { return }
        guard !unlockQueue.isEmpty else {
            currentUnlock = nil
            return
        }
        currentUnlock = unlockQueue.removeFirst()
        accessibilityPreferences.triggerNotificationHaptic(type: .success)
    }
}

private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(WWFDesign.Colors.forestDark)
            content
        }
    }
}

private struct OverviewCard: View {
    let icon: String
    let value: String
    let label: String
    let kidsMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(kidsMode ? .title2 : .headline)
                .foregroundColor(WWFDesign.Colors.forestMid)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(WWFDesign.Colors.forestDark)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: kidsMode ? 118 : 96, alignment: .leading)
        .sectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct FilterChips<Value: Identifiable & Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: (Value) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values) { value in
                    Button {
                        selection = value
                    } label: {
                        Text(title(value))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 42)
                            .background(selection == value ? WWFDesign.Colors.forestMid : Color(.secondarySystemGroupedBackground))
                            .foregroundColor(selection == value ? .white : WWFDesign.Colors.forestDark)
                            .clipShape(Capsule())
                    }
                    .accessibilityAddTraits(selection == value ? [.isSelected] : [])
                }
            }
        }
    }
}

private struct BadgeTile: View {
    let badge: LocalBadge
    let isUnlocked: Bool
    let kidsMode: Bool
    let easyReadMode: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? WWFDesign.Colors.leafGreen.opacity(0.18) : Color(.tertiarySystemFill))
                    .frame(width: kidsMode ? 70 : 58, height: kidsMode ? 70 : 58)
                Image(systemName: iconName)
                    .font(kidsMode ? .title : .title2)
                    .foregroundColor(isUnlocked ? WWFDesign.Colors.forestMid : .secondary)
            }
            Text(displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(WWFDesign.Colors.forestDark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(isUnlocked ? rarityTitle(badge.rarity) : (easyReadMode ? "Da scoprire" : badge.unlockHint ?? "Da scoprire"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: kidsMode ? 158 : 138)
        .sectionCard()
        .opacity(isUnlocked ? 1 : 0.72)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUnlocked ? "Badge sbloccato: \(badge.name)" : "Badge bloccato: \(displayName)")
    }

    private var displayName: String {
        if badge.isHidden && !isUnlocked {
            "Badge segreto"
        } else if kidsMode && badge.category == "kids" {
            "Missione speciale"
        } else {
            badge.name
        }
    }

    private var iconName: String {
        if badge.isHidden && !isUnlocked { return "questionmark.circle.fill" }
        return badge.iconName ?? "rosette"
    }
}

private struct SpeciesTile: View {
    let species: LocalSpecies
    let isUnlocked: Bool
    let kidsMode: Bool
    let easyReadMode: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                    .fill(isUnlocked ? WWFDesign.Colors.forestMid.opacity(0.1) : Color(.tertiarySystemFill))
                    .frame(height: kidsMode ? 86 : 72)
                Image(systemName: isUnlocked ? (species.iconName ?? "leaf.fill") : "leaf")
                    .font(kidsMode ? .largeTitle : .title)
                    .foregroundColor(isUnlocked ? WWFDesign.Colors.forestMid : .secondary)
                    .opacity(isUnlocked ? 1 : 0.5)
            }
            Text(isUnlocked ? species.name : (kidsMode ? "Sagoma misteriosa" : "Specie da scoprire"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(WWFDesign.Colors.forestDark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(isUnlocked ? rarityTitle(species.rarity) : (easyReadMode ? "Non ancora trovata" : "Continua a esplorare"))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: kidsMode ? 168 : 146)
        .sectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUnlocked ? "Specie scoperta: \(species.name), rarità \(rarityTitle(species.rarity))" : "Specie non ancora scoperta")
    }
}

private struct TrailAchievementCard: View {
    let trail: Trail
    let progress: LocalTrailProgress?
    let easyReadMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.seal.fill" : "map.fill")
                    .foregroundColor(isCompleted ? WWFDesign.Colors.leafGreen : WWFDesign.Colors.forestMid)
                Text(trail.localizedName)
                    .font(.headline)
                    .foregroundColor(WWFDesign.Colors.forestDark)
                    .lineLimit(2)
                Spacer()
                Text(isCompleted ? "Completato" : "\(completionPercent)%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isCompleted ? WWFDesign.Colors.leafGreen : .secondary)
            }
            ProgressView(value: Double(completionPercent) / 100)
                .tint(isCompleted ? WWFDesign.Colors.leafGreen : WWFDesign.Colors.forestMid)
            Text(easyReadMode ? "\(visitedCount) tappe visitate." : "\(visitedCount) POI visitati su \(max(1, trail.steps.count)). Ricompensa \(isCompleted ? "ottenuta" : "in corso").")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trail.localizedName). \(completionPercent) percento completato.")
    }

    private var visitedCount: Int {
        progress?.visits.count ?? 0
    }

    private var completionPercent: Int {
        guard !trail.steps.isEmpty else { return 0 }
        return min(100, Int((Double(visitedCount) / Double(trail.steps.count)) * 100))
    }

    private var isCompleted: Bool {
        progress?.status == .completed
    }
}

private struct EventRewardCard: View {
    let event: Event
    let isCompleted: Bool
    let isRegistered: Bool
    let hasCompletionValidation: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "calendar.badge.checkmark" : "calendar")
                .font(.title3)
                .foregroundColor(isCompleted ? WWFDesign.Colors.leafGreen : WWFDesign.Colors.forestMid)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.localizedName)
                    .font(.headline)
                    .foregroundColor(WWFDesign.Colors.forestDark)
                    .lineLimit(2)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if hasCompletionValidation && !isCompleted {
                Image(systemName: "qrcode.viewfinder")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Convalida disponibile con QR o codice")
            }
        }
        .sectionCard()
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        if isCompleted { return "Ricompensa ottenuta" }
        if isRegistered { return "Iscrizione registrata" }
        return event.isUpcoming ? "In programma" : "Da completare"
    }
}

private struct RecentUnlockRow: View, Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(WWFDesign.Colors.forestMid)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(WWFDesign.Colors.forestDark)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(date, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .sectionCard()
    }
}

private struct SpeciesDetailView: View {
    let species: LocalSpecies
    let isUnlocked: Bool
    let easyReadMode: Bool
    let kidsMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: WWFDesign.Radius.hero)
                            .fill(WWFDesign.Colors.forestMid.opacity(isUnlocked ? 0.12 : 0.08))
                            .frame(height: kidsMode ? 190 : 160)
                        Image(systemName: isUnlocked ? (species.iconName ?? "leaf.fill") : "leaf")
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
                            Label(rarityTitle(species.rarity), systemImage: "sparkle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(WWFDesign.Colors.forestMid)
                        }
                    }
                    .sectionCard()
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

    private var description: String {
        if easyReadMode, let text = species.descriptionEasyRead, !text.isEmpty {
            return text
        }
        if kidsMode, let text = species.descriptionKids, !text.isEmpty {
            return text
        }
        return species.speciesDescription
    }
}

private struct UnlockCelebrationView: View {
    let unlock: ProfileUnlock
    let kidsMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: kidsMode ? "sparkles" : "seal.fill")
                .font(.system(size: 52))
                .foregroundColor(WWFDesign.Colors.forestMid)
                .accessibilityHidden(true)
            Text(unlock.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(unlock.detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Continua") { dismiss() }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(WWFDesign.Colors.forestMid)
                .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        }
        .padding(22)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func sectionCard() -> some View {
        self
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private func rarityTitle(_ rarity: String) -> String {
    switch rarity {
    case "common": "Comune"
    case "uncommon": "Non comune"
    case "rare": "Rara"
    case "legendary": "Leggendaria"
    default: rarity.capitalized
    }
}
