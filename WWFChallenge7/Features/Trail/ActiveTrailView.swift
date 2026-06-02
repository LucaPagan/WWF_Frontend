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

private struct ActiveTrailActionButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(fill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.22), lineWidth: 1))
            .shadow(color: WWFDesign.Colors.forestDark.opacity(configuration.isPressed ? 0.04 : 0.09), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct ActiveTrailPillButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(fill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.22), lineWidth: 1))
            .shadow(color: WWFDesign.Colors.forestDark.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 3 : 7, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - ActiveTrailView

struct ActiveTrailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var gamificationService: GamificationService
    @ObservedObject private var localizer = LocalizationManager.shared
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences

    // Navigation state
    @State private var completedPOIIds: Set<UUID> = []
    @State private var navigationState: TrailNavigationState = .atStart
    @State private var mapDisplayMode: MapDisplayMode = .flat2D
    @State private var instructionPopup: InstructionPopupContent?
    @ObservedObject private var voiceService = VoiceService.shared

    // Scanner / modals
    @State private var showScanner     = false
    @State private var showPOIModal    = false
    @State private var scannedPOI: POI? = nil
    @State private var showQRErrorAlert = false
    @State private var qrErrorMessage  = ""
    @State private var showManualCode  = false
    @State private var progressRecord: LocalTrailProgress?
    @State private var globalAlerts: [POI] = []
    @State private var showExitConfirmation = false

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

    private var navigationSpeechID: String {
        switch navigationState {
        case .atStart:
            return "start-\(trail.id)"
        case .navigatingTo(let step):
            return "step-\(step.id)"
        case .poiReached(let poi):
            return "poi-\(poi.id)"
        case .completed:
            return "completed-\(trail.id)"
        }
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Map ──────────────────────────────────────────────────────────
            WWFDesign.Colors.backgroundCream
                .ignoresSafeArea()

            mapLayer
                .ignoresSafeArea()

            // ── Bottom navigation card ────────────────────────────────────────
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
                    WWFDesign.Colors.cardCream
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(WWFDesign.Colors.organicOutline.opacity(0.22), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(WWFDesign.Colors.organicInset.opacity(0.64), lineWidth: 1)
                                .padding(4)
                        )
                        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 10, x: 0, y: -3)
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // ── Top-leading controls ──────────────────────────────────────────────
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                exitTrailButton
                mapSwitcherMenu
            }
            .padding(.horizontal)
        }
        // ── Progress label ───────────────────────────────────────────────────
        .overlay(alignment: .topTrailing) {
            Text("\(completedPOIIds.count)/\(trail.steps.count)")
                .font(WWFDesign.Typography.caption.weight(.bold))
                .foregroundColor(WWFDesign.Colors.forestDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WWFDesign.Colors.cardCream.opacity(0.92))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.22), lineWidth: 1))
                .shadow(color: WWFDesign.Colors.forestDark.opacity(0.06), radius: 6, x: 0, y: 2)
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
                        .font(WWFDesign.Typography.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(WWFDesign.Colors.forestMid)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.20), lineWidth: 1))
                        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.10), radius: 8, x: 0, y: 3)
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
                    case .alreadyVisited(let visited):
                        openVisitedPOI(visited)
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
        .sheet(item: $instructionPopup) { content in
            InstructionTextPopup(content: content)
        }
        .alert(localizer.localizedString(for: "qr_error"), isPresented: $showQRErrorAlert) {
            Button(localizer.localizedString(for: "ok_button"), role: .cancel) {}
        } message: {
            Text(qrErrorMessage)
        }
        .alert(localizer.localizedString(for: "exit_trail_title"), isPresented: $showExitConfirmation) {
            Button(localizer.localizedString(for: "cancel"), role: .cancel) {}
            Button(localizer.localizedString(for: "exit_and_reset"), role: .destructive) {
                resetProgressAndExit()
            }
        } message: {
            Text(localizer.localizedString(for: "exit_trail_message"))
        }
        .onAppear {
            gamificationService.isNavigatingTrail = true
            loadGlobalAlerts()
            loadProgress()
        }
        .onDisappear {
            VoiceService.shared.stop()
            gamificationService.isNavigatingTrail = false
            gamificationService.flushDeferredRewards()
        }
        .onChange(of: navigationSpeechID) {
            VoiceService.shared.stop()
            instructionPopup = nil
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
                    navigationState: navigationState,
                    onCompletedPOITap: openVisitedPOI
                )
            case .model3D(let mapType):
                Visitor3DMapView(
                    trail: trail,
                    completedPOIIds: completedPOIIds,
                    currentStepPOIId: currentStep?.poi?.id,
                    currentNormalizedPosition: currentNormalizedPosition,
                    navigationState: navigationState,
                    mapType: mapType,
                    onCompletedPOITap: openVisitedPOI
                )
            }
        }
    }

    // MARK: Map switcher menu

    private var exitTrailButton: some View {
        Button {
            showExitConfirmation = true
        } label: {
            Label(localizer.localizedString(for: "exit_trail"), systemImage: "rectangle.portrait.and.arrow.right")
                .font(WWFDesign.Typography.chipLabel.weight(.bold))
        }
        .buttonStyle(ActiveTrailPillButtonStyle(fill: WWFDesign.Colors.cardCream))
        .accessibilityLabel(localizer.localizedString(for: "exit_trail"))
        .accessibilityHint(localizer.localizedString(for: "exit_trail_accessibility_hint"))
        .padding(.top, 8)
    }

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
            Label(currentMapLabel, systemImage: mapIconName)
                .font(WWFDesign.Typography.chipLabel.weight(.bold))
        }
        .buttonStyle(ActiveTrailPillButtonStyle(fill: WWFDesign.Colors.leafLight))
        .accessibilityLabel(localizer.localizedString(for: "change_map_type"))
        .accessibilityHint(localizer.localizedString(for: "change_map_type_hint"))
    }

    private var mapIconName: String {
        switch mapDisplayMode {
        case .flat2D:          return "view.3d"
        case .model3D(let t):  return t == .realistic ? "arkit" : "map"
        }
    }

    private var currentMapLabel: String {
        switch mapDisplayMode {
        case .flat2D:
            return localizer.localizedString(for: "flat_2d_map")
        case .model3D(let type):
            return localizer.localizedString(for: type == .realistic ? "map_type_realistic" : "map_type_basic")
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
                nextStepInstructions: trail.sortedSteps.first?.instructions,
                showsFullTextAction: shouldShowStartPopup,
                isSpeaking: voiceService.isSpeaking,
                onShowFullText: showStartInstructions,
                onToggleAudio: {
                    toggleSpeech(text: startSpeechText)
                }
            )
        case .navigatingTo(let step):
            NavigatingCard(
                step: step,
                showsFullTextAction: isLongInstruction(step.instructions),
                isSpeaking: voiceService.isSpeaking,
                onShowFullText: {
                    showStepInstructions(step)
                },
                onToggleAudio: {
                    toggleSpeech(text: step.instructions)
                }
            )
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
                VoiceService.shared.stop()
                if let first = trail.sortedSteps.first {
                    navigationState = .navigatingTo(first)
                    gamificationService.trailStarted(trail)
                }
            } label: {
                Label(LocalizationManager.shared.localizedString(for: "start_trail"), systemImage: "figure.hiking")
                    .font(WWFDesign.Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ActiveTrailActionButtonStyle(fill: WWFDesign.Colors.forestLight))
            .accessibilityLabel("Inizia percorso")
            .accessibilityHint("Avvia la navigazione del sentiero")

        case .navigatingTo:
            Button { showScanner = true } label: {
                Label(LocalizationManager.shared.localizedString(for: "scan_qr"), systemImage: "qrcode.viewfinder")
                    .font(WWFDesign.Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ActiveTrailActionButtonStyle(fill: WWFDesign.Colors.forestMid))
            .accessibilityLabel("Scansiona QR code")
            .accessibilityHint("Apri la fotocamera per scansionare il QR code del punto di interesse")

        case .poiReached:
            EmptyView()

        case .completed:
            Button { restartTrail() } label: {
                Label(LocalizationManager.shared.localizedString(for: "restart_trail"), systemImage: "arrow.counterclockwise")
                    .font(WWFDesign.Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ActiveTrailActionButtonStyle(fill: WWFDesign.Colors.leafLight, foreground: .black))
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
        case .alreadyVisited(let visited):
            openVisitedPOI(visited)
        case .notInDownloadedTrail, .unknown:
            qrErrorMessage = "\(localizer.localizedString(for: "qr_not_related"))\n\n\(localizer.localizedString(for: "scanned")):\n\(clean)"
        }
    }

    // MARK: Modal dismiss

    private func handleModalDismiss() {
        VoiceService.shared.stop()
        if isCompleted {
            navigationState = .completed
            completeProgressIfNeeded()
        } else if let next = currentStep {
            navigationState = .navigatingTo(next)
        }
    }

    private func openVisitedPOI(_ poi: POI) {
        VoiceService.shared.stop()
        scannedPOI = poi
        showScanner = false
        showManualCode = false
        showPOIModal = true
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
        VoiceService.shared.stop()
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
                gamificationService.poiScanned(poi: poi, trail: trail, progress: progressRecord, visit: visit)
            }
            progressRecord.status = isCompleted ? .completed : .inProgress
            progressRecord.completedAt = isCompleted ? Date() : progressRecord.completedAt
            progressRecord.updatedAt = Date()
            progressRecord.needsSync = true
            try? modelContext.save()
            if isCompleted {
                gamificationService.trailCompleted(trail, progress: progressRecord)
            }
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
        gamificationService.trailCompleted(trail, progress: progressRecord)
        Task { await syncManager.pushPendingProgress(deviceId: userSession.deviceId) }
    }

    private func resetProgressAndExit() {
        resetLocalProgress()
        dismiss()
    }

    private func restartTrail() {
        resetLocalProgress()
        gamificationService.trailStarted(trail)
    }

    private func resetLocalProgress() {
        VoiceService.shared.stop()
        let pathId = trail.id
        let descriptor = FetchDescriptor<LocalTrailProgress>(
            predicate: #Predicate { $0.pathId == pathId }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        for record in records {
            modelContext.delete(record)
        }

        let progress = LocalTrailProgress(pathId: trail.id)
        modelContext.insert(progress)
        try? modelContext.save()

        progressRecord = progress
        completedPOIIds = []
        scannedPOI = nil
        qrErrorMessage = ""
        navigationState = .atStart
    }

    private var startSpeechText: String {
        [
            trail.startPointName,
            trail.startPointDescription,
            trail.sortedSteps.first?.instructions
        ]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ". ")
    }

    private var startPopupText: String {
        [
            trail.startPointDescription,
            trail.sortedSteps.first?.instructions
        ]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    private var shouldShowStartPopup: Bool {
        isLongInstruction(trail.startPointDescription) ||
        isLongInstruction(trail.sortedSteps.first?.instructions ?? "")
    }

    private func toggleSpeech(text: String) {
        if voiceService.isSpeaking {
            voiceService.stop()
        } else {
            voiceService.speak(text, languageCode: localizer.preferredLanguage)
        }
    }

    private func showStartInstructions() {
        guard shouldShowStartPopup else { return }
        instructionPopup = InstructionPopupContent(
            title: trail.startPointName,
            subtitle: localizer.localizedString(for: "you_are_here"),
            body: startPopupText,
            metadata: nil,
            tint: WWFDesign.Colors.forestLight
        )
    }

    private func showStepInstructions(_ step: TrailStep) {
        guard isLongInstruction(step.instructions) else { return }
        instructionPopup = InstructionPopupContent(
            title: step.poi?.localizedName ?? localizer.localizedString(for: "go_to"),
            subtitle: localizer.localizedString(for: "go_to"),
            body: step.instructions,
            metadata: "\(step.distanceMeters) m - ~\(step.estimatedMinutes) min",
            tint: WWFDesign.Colors.accentAmbra
        )
    }

    private func isLongInstruction(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 130 || trimmed.contains("\n")
    }
}

// MARK: - StartPointCard

private struct StartPointCard: View {
    let name: String
    let description: String
    let nextStepInstructions: String?
    let showsFullTextAction: Bool
    let isSpeaking: Bool
    let onShowFullText: () -> Void
    let onToggleAudio: () -> Void
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                CardBlobShape()
                    .fill(WWFDesign.Colors.forestLight)
                CardBlobShape()
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.38), lineWidth: 1.2)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "flag.fill")
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(WWFDesign.Colors.forestLight)
                            .padding(.top, 7)
                        Text("\(localizer.localizedString(for: "you_are_here")): \(name)")
                            .font(WWFDesign.Typography.trailNameLarge)
                            .foregroundColor(.black)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        if showsFullTextAction {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(WWFDesign.Colors.forestMid)
                                .accessibilityHidden(true)
                        }

                        SpeechToggleButton(
                            isSpeaking: isSpeaking,
                            tint: WWFDesign.Colors.forestLight,
                            action: onToggleAudio
                        )
                    }
                    Text(description)
                        .font(WWFDesign.Typography.trailDescBody)
                        .foregroundColor(.black.opacity(0.8))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let instructions = nextStepInstructions {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.turn.up.right")
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(WWFDesign.Colors.warningBody)
                            .padding(.top, 2)
                        Text(instructions)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.trailing, 20)
            .padding(.leading, 12)
        }
        .background(WWFDesign.Colors.cardCream)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(WWFDesign.Colors.organicInset.opacity(0.66), lineWidth: 1).padding(4))
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.07), radius: 7, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            if showsFullTextAction {
                onShowFullText()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Punto di partenza: \(name). \(description). \(nextStepInstructions ?? "")")
    }
}

// MARK: - NavigatingCard

private struct NavigatingCard: View {
    let step: TrailStep
    let showsFullTextAction: Bool
    let isSpeaking: Bool
    let onShowFullText: () -> Void
    let onToggleAudio: () -> Void
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                CardBlobShape()
                    .fill(Color.orange)
                CardBlobShape()
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.38), lineWidth: 1.2)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 7)
                        if let poi = step.poi {
                            Text("\(localizer.localizedString(for: "go_to")): \(poi.localizedName)")
                                .font(WWFDesign.Typography.trailNameLarge)
                                .foregroundColor(.black)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        if showsFullTextAction {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(WWFDesign.Colors.warningBody)
                                .accessibilityHidden(true)
                        }

                        SpeechToggleButton(
                            isSpeaking: isSpeaking,
                            tint: WWFDesign.Colors.accentAmbra,
                            action: onToggleAudio
                        )
                    }
                    Text(localizer.localizedString(for: "scan_qr_desc"))
                        .font(WWFDesign.Typography.trailDescBody)
                        .foregroundColor(.black.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(WWFDesign.Typography.caption)
                        .foregroundColor(WWFDesign.Colors.warningBody)
                        .padding(.top, 2)
                    Text(step.instructions)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(WWFDesign.Colors.warningBody)
                        Text("\(step.distanceMeters) m")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(WWFDesign.Colors.warningBody)
                        Text("~\(step.estimatedMinutes) min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.trailing, 20)
            .padding(.leading, 12)
        }
        .background(WWFDesign.Colors.cardCream)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(WWFDesign.Colors.organicInset.opacity(0.66), lineWidth: 1).padding(4))
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.07), radius: 7, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            if showsFullTextAction {
                onShowFullText()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prossima tappa: \(step.poi?.localizedName ?? ""). \(step.instructions). Distanza: \(step.distanceMeters) metri, circa \(step.estimatedMinutes) minuti.")
    }
}

// MARK: - Shared Card Pieces

private struct SpeechToggleButton: View {
    let isSpeaking: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isSpeaking ? .white : tint)
                .frame(width: 38, height: 38)
                .background(isSpeaking ? tint : tint.opacity(0.13))
                .clipShape(Circle())
                .overlay(Circle().stroke(WWFDesign.Colors.organicOutline.opacity(0.32), lineWidth: 1.1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSpeaking ? "Interrompi sintesi vocale" : "Leggi istruzioni ad alta voce")
    }
}

private struct InstructionPopupContent: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let body: String
    let metadata: String?
    let tint: Color
}

private struct InstructionTextPopup: View {
    let content: InstructionPopupContent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(WWFDesign.Colors.organicOutline.opacity(0.5))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let subtitle = content.subtitle {
                        Text(subtitle)
                            .font(WWFDesign.Typography.chipLabel.weight(.bold))
                            .foregroundColor(content.tint)
                    }

                    Text(content.title)
                        .font(WWFDesign.Typography.trailNameLarge)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    if let metadata = content.metadata {
                        Text(metadata)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.65))
                    }
                }

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(WWFDesign.Colors.organicOutline.opacity(0.30), lineWidth: 1.1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chiudi")
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)

            ScrollView {
                Text(content.body)
                    .font(WWFDesign.Typography.trailDescBody)
                    .foregroundColor(.black.opacity(0.86))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(WWFDesign.Colors.cardCream)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1)
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }
        }
        .background(WWFDesign.Colors.cardCream.opacity(0.98))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - POIReachedCard

private struct POIReachedCard: View {
    let poi: POI
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                CardBlobShape()
                    .fill(WWFDesign.Colors.leafGreen)
                CardBlobShape()
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.38), lineWidth: 1.2)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(WWFDesign.Typography.caption)
                        .foregroundColor(WWFDesign.Colors.leafGreen)
                    Text("\(localizer.localizedString(for: "reached")): \(poi.localizedName)")
                        .font(WWFDesign.Typography.trailNameLarge)
                        .foregroundColor(.black)
                }
                Text(localizer.localizedString(for: "view_info"))
                    .font(WWFDesign.Typography.trailDescBody)
                    .foregroundColor(.black.opacity(0.8))
            }
            .padding(.vertical, 20)
            .padding(.trailing, 20)
            .padding(.leading, 12)

            Spacer()
        }
        .background(WWFDesign.Colors.cardCream)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(WWFDesign.Colors.organicInset.opacity(0.66), lineWidth: 1).padding(4))
        .shadow(color: WWFDesign.Colors.forestDark.opacity(0.07), radius: 7, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Raggiunto: \(poi.localizedName). Tocca per visualizzare le informazioni.")
    }
}
