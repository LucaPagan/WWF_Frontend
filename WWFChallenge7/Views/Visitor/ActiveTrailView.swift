import SwiftUI

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
    @ObservedObject private var localizer = LocalizationManager.shared

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
                // Ensure ProgressBar is a valid struct in your project.
                // Replace with ProgressView(value: progressFraction) if you don't have it.
                ProgressView(value: progressFraction)
                    .progressViewStyle(LinearProgressViewStyle(tint: WWFStyle.Colors.green))
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
            }
        }
        // ── Top-leading controls ──────────────────────────────────────────────
        .overlay(alignment: .topLeading) {
            VStack(spacing: 16) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white, Color.black.opacity(0.4))
                }

                mapSwitcherMenu
            }
            .padding()
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
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        // ── Sheets / Alerts ───────────────────────────────────────────────────
        .sheet(isPresented: $showScanner) {
            QRScannerView { payload in handleQRScan(payload: payload) }
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
            navigationState = .atStart
        }
    }

    // MARK: Map layer

    @ViewBuilder
    private var mapLayer: some View {
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
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 44, height: 44)
                Image(systemName: mapIconName)
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(.top, 4)
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
                    .background(WWFStyle.Colors.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

        case .navigatingTo:
            Button { showScanner = true } label: {
                Label(LocalizationManager.shared.localizedString(for: "scan_qr"), systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WWFStyle.Colors.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

        case .poiReached:
            EmptyView()

        case .completed:
            Button { dismiss() } label: {
                Label(LocalizationManager.shared.localizedString(for: "back_to_home"), systemImage: "house.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WWFStyle.Colors.darkGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: QR handler

    private func handleQRScan(payload: String) {
        showScanner = false
        let clean = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trail.isActive else {
            qrErrorMessage = localizer.localizedString(for: "trail_not_active")
            showQRErrorAlert = true
            return
        }

        let allPOIs = trail.sortedSteps.compactMap { $0.poi }

        guard let matched = allPOIs.first(where: { $0.qrPayload == clean }) else {
            let expected = allPOIs.map { $0.qrPayload }.joined(separator: "\n• ")
            let notRelated = localizer.localizedString(for: "qr_not_related")
            let scanned = localizer.localizedString(for: "scanned")
            let expectedOneOf = localizer.localizedString(for: "expected_one_of")
            let fallbackEmpty = localizer.localizedString(for: "no_pois_in_trail")
            
            qrErrorMessage = """
            \(notRelated)

            📷 \(scanned):
            \(clean)

            ✅ \(expectedOneOf):
            • \(expected.isEmpty ? fallbackEmpty : expected)
            """
            showQRErrorAlert = true
            return
        }

        if completedPOIIds.contains(matched.id) {
            qrErrorMessage = localizer.localizedString(for: "poi_already_visited")
            showQRErrorAlert = true
            return
        }

        completedPOIIds.insert(matched.id)
        scannedPOI = matched
        navigationState = .poiReached(matched)
        showPOIModal = true
    }

    // MARK: Modal dismiss

    private func handleModalDismiss() {
        if isCompleted {
            navigationState = .completed
        } else if let next = currentStep {
            navigationState = .navigatingTo(next)
        }
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
                    Circle().fill(WWFStyle.Colors.green).frame(width: 36, height: 36)
                    Image(systemName: "flag.fill").font(.caption).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(LocalizationManager.shared.localizedString(for: "you_are_here")): \(name)").font(.subheadline).fontWeight(.bold)
                    Text(description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
            }
            if let instructions = nextStepInstructions {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundColor(WWFStyle.Colors.green).font(.caption)
                    Text(instructions).font(.caption).foregroundColor(.secondary).lineLimit(3)
                }
            }
        }
        .padding()
        .background(WWFStyle.Colors.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        Text("\(LocalizationManager.shared.localizedString(for: "go_to")): \(poi.localizedName)").font(.subheadline).fontWeight(.bold)
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
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - POIReachedCard

struct POIReachedCard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.green).frame(width: 36, height: 36)
                Image(systemName: "checkmark").font(.caption).fontWeight(.bold).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(LocalizationManager.shared.localizedString(for: "reached")): \(poi.localizedName)").font(.subheadline).fontWeight(.bold)
                Text(LocalizationManager.shared.localizedString(for: "view_info")).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - CompletedBanner (Mock for component)
/*struct CompletedBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue).frame(width: 36, height: 36)
                Image(systemName: "star.fill").font(.caption).fontWeight(.bold).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Trail Completed!").font(.subheadline).fontWeight(.bold)
                Text("Great job navigating the trail.").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}*/
