//
//  ActiveTrailView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//  Redesigned — Maggio 2026
//

import SwiftUI
import SwiftData

// MARK: - Stato navigazione

enum TrailNavigationState {
    case atStart
    case navigatingTo(TrailStep)
    case poiReached(POI)
    case completed
}

// MARK: - Map Display Mode

enum MapDisplayMode: Equatable {
    case flat2D
    case model3D(ThreeDMapType)
}

// MARK: - ActiveTrailView

struct ActiveTrailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var userSession: UserSession
    @ObservedObject private var localizer = LocalizationManager.shared
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences

    // Navigation state
    @State private var completedPOIIds: Set<UUID> = []
    @State private var navigationState: TrailNavigationState = .atStart
    @State private var mapDisplayMode: MapDisplayMode = .flat2D

    // Scanner / modals
    @State private var showScanner     = false
    @State private var showPOIModal    = false
    @State private var scannedPOI: POI? = nil
    @State private var showQRErrorAlert = false
    @State private var qrErrorMessage  = ""
    @State private var showManualCode  = false
    @State private var progressRecord: LocalTrailProgress?
    @State private var globalAlerts: [POI] = []

    // MARK: Computed helpers

    private var isRealistic: Bool {
        if case .model3D(let t) = mapDisplayMode { return t == .realistic }
        return false
    }

    var currentStep: TrailStep? {
        trail.currentStep(completedPOIIds: completedPOIIds)
    }

    var progressFraction: Double {
        guard !trail.steps.isEmpty else { return 0 }
        return Double(completedPOIIds.count) / Double(trail.steps.count)
    }

    var isCompleted: Bool {
        completedPOIIds.count >= trail.steps.count && !trail.steps.isEmpty
    }

    var currentNormalizedPosition: CGPoint {
        switch navigationState {
        case .atStart:
            return CGPoint(x: trail.startX, y: trail.startY)
        case .navigatingTo:
            if let lastPOI = trail.sortedSteps
                .filter({ step in
                    guard let poi = step.poi else { return false }
                    return completedPOIIds.contains(poi.id)
                })
                .sorted(by: { $0.stepOrder > $1.stepOrder })
                .first?.poi {
                return CGPoint(x: lastPOI.x, y: lastPOI.y)
            }
            return CGPoint(x: trail.startX, y: trail.startY)
        case .poiReached(let poi):
            return CGPoint(x: poi.x, y: poi.y)
        case .completed:
            return trail.sortedSteps.last?.poi.map { CGPoint(x: $0.x, y: $0.y) }
                ?? CGPoint(x: trail.startX, y: trail.startY)
        }
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Map ──────────────────────────────────────────────────────────
            mapLayer
                .ignoresSafeArea()

            // ── Bottom navigation panel ───────────────────────────────────────
            VStack(spacing: 0) {
                ProgressView(value: progressFraction)
                    .tint(WWFDesign.Colors.forestLight)
                    .frame(height: 4)

                VStack(spacing: 12) {
                    navigationCard
                    actionButton
                }
                .padding()
                .background(
                    Color(.systemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -4)
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        // ── Top-leading controls ──────────────────────────────────────────────
        .overlay(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Dimissione vetrosa organica
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(WWFDesign.Colors.forestMid.opacity(0.35))
                            .background(.ultraThinMaterial)
                            .overlay(
                                Circle().stroke(WWFDesign.Colors.leafGreen.opacity(0.35), lineWidth: 0.5)
                            )
                            .clipShape(Circle())
                        
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(WWFDesign.Colors.leafLight)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                }
                .accessibilityLabel("Chiudi percorso")
                .padding(.top, 8)

                mapSwitcherMenu
            }
            .padding(.horizontal)
        }
        // ── Progress label ───────────────────────────────────────────────────
        .overlay(alignment: .topTrailing) {
            Text("\(completedPOIIds.count)/\(trail.steps.count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
                .padding(.top, 8)
                .padding(.trailing, 16)
                .accessibilityLabel("Progresso: \(completedPOIIds.count) su \(trail.steps.count) tappe completate")
        }
        // ── Sheets / Alerts ───────────────────────────────────────────────────
        .sheet(isPresented: $showScanner) {
            ZStack(alignment: .bottom) {
                QRScannerView { payload in handleQRScan(payload: payload) }
                    .ignoresSafeArea()
                
                Button {
                    showManualCode = true
                } label: {
                    Text(localizer.localizedString(for: "manual_code_entry"))
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding()
                        .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showManualCode) {
                NumericCodeEntryView(
                    allowedPOIIds: Set(trail.sortedSteps.compactMap { $0.poi?.id }),
                    allowGlobalAlerts: true
                ) { poi in
                    showManualCode = false
                    showScanner = false
                    let resolver = OfflineQRResolver(trail: trail, globalAlerts: globalAlerts, completedPOIIds: completedPOIIds)
                    switch resolver.resolve(numericCode: poi.numericCode) {
                    case .trailPOI(let matched):
                        markVisited(matched, source: .numericCode, qrPayload: matched.qrPayload)
                    case .globalAlert(let alert):
                        scannedPOI = alert
                    case .alreadyVisited:
                        qrErrorMessage = localizer.localizedString(for: "poi_already_visited")
                        showQRErrorAlert = true
                    case .notInDownloadedTrail, .unknown:
                        qrErrorMessage = localizer.localizedString(for: "qr_not_related")
                        showQRErrorAlert = true
                    }
                }
            }
            .onDisappear {
                if scannedPOI != nil {
                    showPOIModal = true
                } else if !qrErrorMessage.isEmpty {
                    showQRErrorAlert = true
                }
            }
        }
        .sheet(isPresented: $showPOIModal, onDismiss: handleModalDismiss) {
            if let poi = scannedPOI {
                POIModalView(poi: poi, onContinue: { showPOIModal = false })
            }
        }
        .alert(localizer.localizedString(for: "qr_error"), isPresented: $showQRErrorAlert) {
            Button(localizer.localizedString(for: "ok_button"), role: .cancel) {}
        } message: {
            Text(qrErrorMessage)
        }
        .onAppear {
            loadGlobalAlerts()
            loadProgress()
        }
    }

    // MARK: Map layer

    @ViewBuilder
    private var mapLayer: some View {
        if accessibilityPreferences.shouldDefaultToListView {
            PathListView(trail: trail)
        } else {
            switch mapDisplayMode {
            case .flat2D:
                VisitorMapView(
                    trail: trail,
                    completedPOIIds: completedPOIIds,
                    currentStepPOIId: currentStep?.poi?.id,
                    currentNormalizedPosition: currentNormalizedPosition,
                    navigationState: navigationState
                )
            case .model3D(let mapType):
                Visitor3DMapView(
                    trail: trail,
                    completedPOIIds: completedPOIIds,
                    currentStepPOIId: currentStep?.poi?.id,
                    currentNormalizedPosition: currentNormalizedPosition,
                    navigationState: navigationState,
                    mapType: mapType
                )
            }
        }
    }

    // MARK: Map switcher menu

    private var mapSwitcherMenu: some View {
        Menu {
            Button {
                withAnimation { mapDisplayMode = .flat2D }
            } label: {
                Label(localizer.localizedString(for: "flat_2d_map"), systemImage: "map")
            }

            Divider()

            ForEach(ThreeDMapType.allCases) { type in
                Button {
                    withAnimation { mapDisplayMode = .model3D(type) }
                } label: {
                    let key = type == .realistic ? "map_type_realistic" : "map_type_basic"
                    Label(localizer.localizedString(for: key), systemImage: type == .realistic ? "arkit" : "view.3d")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(WWFDesign.Colors.forestMid.opacity(0.35))
                    .background(.ultraThinMaterial)
                    .overlay(
                        Circle().stroke(WWFDesign.Colors.leafGreen.opacity(0.35), lineWidth: 0.5)
                    )
                    .clipShape(Circle())
                
                Image(systemName: mapIconName)
                    .font(.headline)
                    .foregroundColor(WWFDesign.Colors.leafLight)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .accessibilityLabel("Cambia tipo mappa")
        .accessibilityHint("Seleziona mappa 2D o 3D")
    }

    private var mapIconName: String {
        switch mapDisplayMode {
        case .flat2D:          return "view.3d"
        case .model3D(let t):  return t == .realistic ? "arkit" : "map"
        }
    }

    // MARK: Navigation card

    @ViewBuilder
    var navigationCard: some View {
        switch navigationState {
        case .atStart:
            StartPointCard(
                name: trail.startPointName,
                description: trail.startPointDescription,
                nextStepInstructions: trail.sortedSteps.first?.instructions
            )
        case .navigatingTo(let step):
            NavigatingCard(step: step)
        case .poiReached(let poi):
            POIReachedCard(poi: poi)
        case .completed:
            CompletedBanner()
        }
    }

    // MARK: Action button

    @ViewBuilder
    var actionButton: some View {
        switch navigationState {
        case .atStart:
            Button {
                if let first = trail.sortedSteps.first {
                    navigationState = .navigatingTo(first)
                }
            } label: {
                Label(LocalizationManager.shared.localizedString(for: "start_trail"), systemImage: "figure.hiking")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WWFDesign.Colors.forestMid)
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    .shadow(color: WWFDesign.Colors.forestMid.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .accessibilityLabel("Inizia percorso")
            .accessibilityHint("Avvia la navigazione del sentiero")

        case .navigatingTo:
            Button { showScanner = true } label: {
                Label(LocalizationManager.shared.localizedString(for: "scan_qr"), systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WWFDesign.Colors.forestMid)
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    .shadow(color: WWFDesign.Colors.forestMid.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .accessibilityLabel("Scansiona QR code")
            .accessibilityHint("Apri la fotocamera per scansionare il QR code del punto di interesse")

        case .poiReached:
            EmptyView()

        case .completed:
            Button { dismiss() } label: {
                Label(LocalizationManager.shared.localizedString(for: "back_to_home"), systemImage: "house.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WWFDesign.Colors.forestDark)
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    .shadow(color: WWFDesign.Colors.forestDark.opacity(0.25), radius: 6, x: 0, y: 3)
            }
        }
    }

    // MARK: QR handler

    private func handleQRScan(payload: String) {
        showScanner = false
        let clean = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        
        scannedPOI = nil
        qrErrorMessage = ""

        guard trail.isActive else {
            qrErrorMessage = localizer.localizedString(for: "trail_not_active")
            return
        }

        let resolver = OfflineQRResolver(trail: trail, globalAlerts: globalAlerts, completedPOIIds: completedPOIIds)
        switch resolver.resolve(payload: clean) {
        case .trailPOI(let matched):
            markVisited(matched, source: .qr, qrPayload: clean)
        case .globalAlert(let alert):
            scannedPOI = alert
        case .alreadyVisited:
            qrErrorMessage = localizer.localizedString(for: "poi_already_visited")
        case .notInDownloadedTrail, .unknown:
            qrErrorMessage = "\(localizer.localizedString(for: "qr_not_related"))\n\n\(localizer.localizedString(for: "scanned")):\n\(clean)"
        }
    }

    // MARK: Modal dismiss

    private func handleModalDismiss() {
        if isCompleted {
            navigationState = .completed
            completeProgressIfNeeded()
        } else if let next = currentStep {
            navigationState = .navigatingTo(next)
        }
    }

    private func loadGlobalAlerts() {
        let descriptor = FetchDescriptor<POI>(
            predicate: #Predicate { $0.isActive == true }
        )
        let pois = (try? modelContext.fetch(descriptor)) ?? []
        globalAlerts = pois.filter { $0.type.isGlobalAlertType }
    }

    private func loadProgress() {
        let pathId = trail.id
        let descriptor = FetchDescriptor<LocalTrailProgress>(
            predicate: #Predicate { $0.pathId == pathId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            progressRecord = existing
            completedPOIIds = Set(existing.visits.map { $0.poiId })
            if existing.status == .completed {
                navigationState = .completed
            } else if let next = currentStep, !completedPOIIds.isEmpty {
                navigationState = .navigatingTo(next)
            } else {
                navigationState = .atStart
            }
        } else {
            let progress = LocalTrailProgress(pathId: trail.id)
            modelContext.insert(progress)
            try? modelContext.save()
            progressRecord = progress
            navigationState = .atStart
        }
    }

    private func markVisited(_ poi: POI, source: LocalVisitSource, qrPayload: String?) {
        guard !completedPOIIds.contains(poi.id) else {
            qrErrorMessage = localizer.localizedString(for: "poi_already_visited")
            showQRErrorAlert = true
            return
        }

        if progressRecord == nil {
            loadProgress()
        }

        completedPOIIds.insert(poi.id)
        scannedPOI = poi
        navigationState = .poiReached(poi)

        if let progressRecord {
            if !progressRecord.visits.contains(where: { $0.poiId == poi.id }) {
                let visit = LocalPOIVisit(
                    progressId: progressRecord.id,
                    poiId: poi.id,
                    source: source,
                    qrPayload: qrPayload
                )
                progressRecord.visits.append(visit)
                modelContext.insert(visit)
            }
            progressRecord.status = isCompleted ? .completed : .inProgress
            progressRecord.completedAt = isCompleted ? Date() : progressRecord.completedAt
            progressRecord.updatedAt = Date()
            progressRecord.needsSync = true
            try? modelContext.save()
            Task { await syncManager.pushPendingProgress(deviceId: userSession.deviceId) }
        }
    }

    private func completeProgressIfNeeded() {
        guard let progressRecord, progressRecord.status != .completed else { return }
        progressRecord.status = .completed
        progressRecord.completedAt = Date()
        progressRecord.updatedAt = Date()
        progressRecord.needsSync = true
        try? modelContext.save()
        Task { await syncManager.pushPendingProgress(deviceId: userSession.deviceId) }
    }
}

// MARK: - StartPointCard

struct StartPointCard: View {
    let name: String
    let description: String
    let nextStepInstructions: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(WWFDesign.Colors.forestLight).frame(width: 36, height: 36)
                    Image(systemName: "flag.fill").font(.caption).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(LocalizationManager.shared.localizedString(for: "you_are_here")): \(name)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(WWFDesign.Colors.forestDark)
                    Text(description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
            }
            if let instructions = nextStepInstructions {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundColor(WWFDesign.Colors.forestLight).font(.caption)
                    Text(instructions).font(.caption).foregroundColor(.secondary).lineLimit(3)
                }
            }
        }
        .padding()
        .background(WWFDesign.Colors.forestLight.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Punto di partenza: \(name). \(description). \(nextStepInstructions ?? "")")
    }
}

// MARK: - NavigatingCard

    struct NavigatingCard: View {
        let step: TrailStep
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.orange).frame(width: 36, height: 36)
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.caption).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if let poi = step.poi {
                            Text("\(LocalizationManager.shared.localizedString(for: "go_to")): \(poi.localizedName)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                        }
                        Text(LocalizationManager.shared.localizedString(for: "scan_qr_desc")).font(.caption).foregroundColor(.secondary)
                    }
                }
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundColor(.orange).font(.caption).padding(.top, 2)
                    Text(step.instructions).font(.caption).foregroundColor(.secondary).lineLimit(4)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Prossima tappa: \(step.poi?.localizedName ?? ""). \(step.instructions). Distanza: \(step.distanceMeters) metri, circa \(step.estimatedMinutes) minuti.")
        }
    }

// MARK: - POIReachedCard

struct POIReachedCard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(WWFDesign.Colors.leafGreen).frame(width: 36, height: 36)
                Image(systemName: "checkmark").font(.caption).fontWeight(.bold).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(LocalizationManager.shared.localizedString(for: "reached")): \(poi.localizedName)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(WWFDesign.Colors.forestDark)
                Text(LocalizationManager.shared.localizedString(for: "view_info")).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(WWFDesign.Colors.leafGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Raggiunto: \(poi.localizedName). Tocca per visualizzare le informazioni.")
    }
}
