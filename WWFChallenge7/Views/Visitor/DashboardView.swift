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
        static let heroTitle      = Font.custom("Georgia", size: 28).weight(.semibold)
        static let heroSubtitle   = Font.system(size: 13, weight: .light)
        static let sectionTitle   = Font.custom("Georgia", size: 19).weight(.semibold)
        static let trailName      = Font.system(size: 15, weight: .medium)
        static let trailDesc      = Font.system(size: 12, weight: .light)
        static let chipLabel      = Font.system(size: 12, weight: .medium)
        static let metaLabel      = Font.system(size: 11, weight: .regular)
        static let badge          = Font.system(size: 10, weight: .medium)
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
    @ObservedObject private var localizer = LocalizationManager.shared

    // POI globali di tipo warning/danger (scaricati indipendentemente dal percorso — SRS §9.1)
    @Query(filter: #Predicate<POI> { $0.typeRawValue == "warning" || $0.typeRawValue == "danger" })
    private var activeWarnings: [POI]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Hero
                    AstroniBannerView()
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // Chip info rapide
                    QuickInfoStripView()

                    // Warning attivi (SRS §4.4 — sempre visibili in evidenza)
                    if !activeWarnings.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(activeWarnings) { poi in
                                GlobalWarningBanner(poi: poi)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Percorsi attivi
                    TrailListSection(
                        trails: trails,
                        localizer: localizer,
                        onSelect: { selectedTrail = $0 }
                    )
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .fullScreenCover(item: $selectedTrail) { trail in
                TrailDetailView(trail: trail)
            }
        }
    }
}

// MARK: - Hero Banner

struct AstroniBannerView: View {
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Sfondo scuro bosco
            RoundedRectangle(cornerRadius: WWFDesign.Radius.hero)
                .fill(WWFDesign.Colors.forestDark)
                .frame(height: 190)

            // Pattern organico — cerchi sfumati che evocano vegetazione
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(WWFDesign.Colors.forestMid)
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: geo.size.width * 0.6, y: -30)
                        .opacity(0.6)

                    Circle()
                        .fill(WWFDesign.Colors.forestLight)
                        .frame(width: 100, height: 100)
                        .blur(radius: 40)
                        .offset(x: geo.size.width * 0.75, y: 60)
                        .opacity(0.25)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.hero))

            // Icona bussola esplorazione decorativa in alto a destra
            Image(systemName: "safari.fill")
                .font(.system(size: 110))
                .foregroundColor(WWFDesign.Colors.leafGreen.opacity(0.07))
                .rotationEffect(.degrees(-15))
                .offset(x: UIScreen.main.bounds.width - 180, y: -20)

            // Contenuto
            VStack(alignment: .leading, spacing: 8) {
                // Badge stato apertura
                HStack(spacing: 6) {
                    Circle()
                        .fill(WWFDesign.Colors.leafGreen)
                        .frame(width: 6, height: 6)
                    Text(localizer.localizedString(for: "oasi_hours"))
                        .font(WWFDesign.Typography.chipLabel)
                        .foregroundColor(WWFDesign.Colors.leafLight)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WWFDesign.Colors.leafGreen.opacity(0.18))
                .overlay(
                    Capsule().stroke(WWFDesign.Colors.leafGreen.opacity(0.35), lineWidth: 0.5)
                )
                .clipShape(Capsule())

                Spacer()

                // Titolo
                VStack(alignment: .leading, spacing: 3) {
                    Text("Oasi degli Astroni")
                        .font(WWFDesign.Typography.heroTitle)
                        .foregroundColor(Color(red: 0.941, green: 0.929, blue: 0.902)) // #f0ede6

                    Text(localizer.localizedString(for: "oasi_subtitle"))
                        .font(WWFDesign.Typography.heroSubtitle)
                        .foregroundColor(Color(red: 0.941, green: 0.929, blue: 0.902).opacity(0.55))
                }
            }
            .padding(20)
            .frame(height: 190, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.hero))
    }
}

// MARK: - Quick Info Strip

struct QuickInfoStripView: View {
    @ObservedObject private var localizer = LocalizationManager.shared

    private let chips: [(icon: String, keyOrText: String, style: WWFChipStyle)] = [
        ("leaf.fill",          "free_entrance",  .green),
        ("wifi.slash",         "offline_ready",  .blue),
        ("qrcode.viewfinder",  "qr_required",    .purple),
        ("map.fill",           "local_map",      .amber),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.icon) { chip in
                    WWFChipView(
                        icon: chip.icon,
                        label: localizer.localizedString(for: chip.keyOrText),
                        style: chip.style
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Chip Component

enum WWFChipStyle {
    case green, blue, purple, amber

    var fillColor: Color {
        switch self {
        case .green:  return Color(red: 0.918, green: 0.953, blue: 0.871)
        case .blue:   return Color(red: 0.902, green: 0.945, blue: 0.984)
        case .purple: return Color(red: 0.933, green: 0.929, blue: 0.996)
        case .amber:  return Color(red: 0.980, green: 0.933, blue: 0.851)
        }
    }

    var borderColor: Color {
        switch self {
        case .green:  return Color(red: 0.753, green: 0.867, blue: 0.592)
        case .blue:   return Color(red: 0.710, green: 0.831, blue: 0.957)
        case .purple: return Color(red: 0.808, green: 0.796, blue: 0.965)
        case .amber:  return Color(red: 0.980, green: 0.780, blue: 0.459)
        }
    }

    var textColor: Color {
        switch self {
        case .green:  return Color(red: 0.231, green: 0.427, blue: 0.067)
        case .blue:   return Color(red: 0.094, green: 0.373, blue: 0.647)
        case .purple: return Color(red: 0.235, green: 0.204, blue: 0.537)
        case .amber:  return Color(red: 0.522, green: 0.310, blue: 0.043)
        }
    }
}

struct WWFChipView: View {
    let icon: String
    let label: String
    let style: WWFChipStyle

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(style.textColor)
            Text(label)
                .font(WWFDesign.Typography.chipLabel)
                .foregroundColor(style.textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(style.fillColor)
        .overlay(
            Capsule().stroke(style.borderColor, lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Global Warning Banner (SRS §4.4 & §9.1)

struct GlobalWarningBanner: View {
    let poi: POI
    @ObservedObject private var localizer = LocalizationManager.shared

    private var isDanger: Bool { poi.type == .danger }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDanger ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isDanger ? WWFDesign.Colors.hardText : WWFDesign.Colors.warningText)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(localizer.localizedString(for: isDanger ? "danger_label" : "warning_label"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDanger ? WWFDesign.Colors.hardText : WWFDesign.Colors.warningText)

                Text(poi.localizedDescription)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(isDanger ? WWFDesign.Colors.hardText.opacity(0.8) : WWFDesign.Colors.warningBody)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(
            isDanger
                ? WWFDesign.Colors.hardFill
                : WWFDesign.Colors.warningFill
        )
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.warning)
                .stroke(
                    isDanger ? WWFDesign.Colors.hardText.opacity(0.25) : WWFDesign.Colors.warningBorder,
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.warning))
    }
}

// MARK: - Trail List Section

struct TrailListSection: View {
    let trails: [Trail]
    let localizer: LocalizationManager
    let onSelect: (Trail) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header sezione
            HStack(alignment: .firstTextBaseline) {
                Text(localizer.localizedString(for: "active_trails"))
                    .font(WWFDesign.Typography.sectionTitle)
                    .foregroundColor(.primary)

                Spacer()

                if !trails.isEmpty {
                    Text("\(trails.count) \(localizer.localizedString(for: "available"))")
                        .font(WWFDesign.Typography.metaLabel)
                        .foregroundColor(.secondary)
                }
            }

            if trails.isEmpty {
                ContentUnavailableView(
                    localizer.localizedString(for: "no_active_trails"),
                    systemImage: "map",
                    description: Text(localizer.localizedString(for: "no_active_trails_desc"))
                )
                .padding(.top, 40)
            } else {
                ForEach(trails) { trail in
                    AstroniTrailCard(trail: trail)
                        .onTapGesture { onSelect(trail) }
                }
            }
        }
    }
}

// MARK: - Trail Card

struct AstroniTrailCard: View {
    let trail: Trail
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
        HStack(spacing: 0) {
            // Accento laterale colorato per difficoltà — scansione visiva immediata
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 10) {
                // Top row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trail.localizedName)
                            .font(WWFDesign.Typography.trailName)
                            .foregroundColor(.primary)

                        Text(trail.localizedDescription)
                            .font(WWFDesign.Typography.trailDesc)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.top, 2)
                }

                // Meta row
                HStack(spacing: 12) {
                    // Badge difficoltà
                    Text(difficultyLabel)
                        .font(WWFDesign.Typography.badge)
                        .fontWeight(.semibold)
                        .tracking(0.3)
                        .foregroundColor(badgeText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeFill)
                        .clipShape(Capsule())

                    // Durata
                    Label {
                        Text("\(trail.estimatedMinutes ?? 60) min")
                            .font(WWFDesign.Typography.metaLabel)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }

                    // Tappe
                    Label {
                        Text("\(trail.steps.count) \(localizer.localizedString(for: "steps_label"))")
                            .font(WWFDesign.Typography.metaLabel)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Previews

#Preview("Dashboard — con percorsi") {
    DashboardView()
        .modelContainer(for: [Trail.self, POI.self], inMemory: true)
}

#Preview("Trail Card — Facile") {
    let trail = Trail(name: "Sentiero del Lago Grande", description: "Passeggiata panoramica attorno al lago vulcanico principale")
    trail.difficulty = .easy
    trail.estimatedMinutes = 60
    trail.isActive = true
    return AstroniTrailCard(trail: trail)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Trail Card — Impegnativo") {
    let trail = Trail(name: "Anello del Cratere", description: "Percorso completo del perimetro vulcanico con dislivello significativo")
    trail.difficulty = .hard
    trail.estimatedMinutes = 150
    trail.isActive = true
    return AstroniTrailCard(trail: trail)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Hero Banner") {
    AstroniBannerView()
        .padding()
}

#Preview("Warning Banner — Danger") {
    let poi = POI(name: "Zona Nord", description: "Sentiero temporaneamente chiuso per manutenzione. Non accedere.", x: 0.0, y: 0.0)
    poi.type = .danger
    return GlobalWarningBanner(poi: poi)
        .padding()
}
