import SwiftUI

// MARK: - Stato navigazione

enum TrailNavigationState {
    case atStart                    // Utente al punto di partenza, non ha ancora scansionato nulla
    case navigatingTo(TrailStep)    // Sta camminando verso un POI
    case poiReached(POI)            // Ha appena scansionato un QR, modale aperto
    case completed                  // Tutti i POI completati
}

// MARK: - ActiveTrailView

struct ActiveTrailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss

    // Stato navigazione
    @State private var completedPOIIds: Set<UUID> = []
    @State private var navigationState: TrailNavigationState = .atStart

    // Scanner e modali
    @State private var showScanner = false
    @State private var showPOIModal = false
    @State private var scannedPOI: POI? = nil
    @State private var showQRErrorAlert = false
    @State private var qrErrorMessage = ""

    // Step corrente
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

    // Posizione attuale sulla mappa (normalizzata)
    var currentNormalizedPosition: CGPoint {
        switch navigationState {
        case .atStart:
            return CGPoint(x: trail.startX, y: trail.startY)
        case .navigatingTo(_):
            // Mostra l'ultimo POI completato, o il punto di partenza
            if let lastCompleted = trail.sortedSteps
                .filter({ step in
                    guard let poi = step.poi else { return false }
                    return completedPOIIds.contains(poi.id)
                })
                .sorted(by: { $0.orderIndex > $1.orderIndex })
                .first?.poi {
                return CGPoint(x: lastCompleted.x, y: lastCompleted.y)
            }
            return CGPoint(x: trail.startX, y: trail.startY)
        case .poiReached(let poi):
            return CGPoint(x: poi.x, y: poi.y)
        case .completed:
            return trail.sortedSteps.last?.poi.map { CGPoint(x: $0.x, y: $0.y) }
                ?? CGPoint(x: trail.startX, y: trail.startY)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: Mappa interattiva (UIScrollView-based, same as manager)
            VisitorMapView(
                trail: trail,
                completedPOIIds: completedPOIIds,
                currentStepPOIId: currentStep?.poi?.id,
                currentNormalizedPosition: currentNormalizedPosition,
                navigationState: navigationState
            )
            .ignoresSafeArea()

            // MARK: Pannello navigazione inferiore
            VStack(spacing: 0) {
                ProgressBar(fraction: progressFraction)
                    .frame(height: 4)

                VStack(spacing: 12) {
                    // Card stato corrente
                    navigationCard

                    // Bottone azione principale
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
        // Bottone chiudi
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, Color.black.opacity(0.4))
                    .padding()
            }
        }
        // Progress label overlay
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
        // Scanner QR
        .sheet(isPresented: $showScanner) {
            QRScannerView { payload in
                handleQRScan(payload: payload)
            }
        }
        // Modale POI
        .sheet(isPresented: $showPOIModal, onDismiss: handleModalDismiss) {
            if let poi = scannedPOI {
                POIModalView(poi: poi, onContinue: {
                    showPOIModal = false
                })
            }
        }
        // Alert QR errato
        .alert("QR non riconosciuto", isPresented: $showQRErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(qrErrorMessage)
        }
        // Stato iniziale
        .onAppear {
            navigationState = .atStart
        }
    }

    // MARK: - Navigation Card

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

    // MARK: - Action Button

    @ViewBuilder
    var actionButton: some View {
        switch navigationState {
        case .atStart:
            Button {
                if let first = trail.sortedSteps.first {
                    navigationState = .navigatingTo(first)
                }
            } label: {
                Label("Inizia il percorso", systemImage: "figure.hiking")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("WWFGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

        case .navigatingTo:
            Button {
                showScanner = true
            } label: {
                Label("Scansiona QR Code", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("WWFGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

        case .poiReached:
            EmptyView()

        case .completed:
            Button { dismiss() } label: {
                Label("Torna alla home", systemImage: "house.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("WWFDarkGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - QR Handler

    private func handleQRScan(payload: String) {
        showScanner = false

        let cleanPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // Controlla che il percorso sia attivo
        guard trail.isActive else {
            qrErrorMessage = "Questo percorso non è attivo. Contatta il gestore dell'oasi."
            showQRErrorAlert = true
            return
        }

        let allPOIs = trail.sortedSteps.compactMap { $0.poi }

        // 1. Il QR appartiene a questo percorso?
        guard let matchedPOI = allPOIs.first(where: { $0.qrPayload == cleanPayload }) else {
            // Costruisci messaggio diagnostico utile
            let expectedPayloads = allPOIs.map { $0.qrPayload }.joined(separator: "\n• ")
            qrErrorMessage = """
            Questo QR code non appartiene al percorso attivo.

            📷 Scansionato:
            \(cleanPayload)

            ✅ Attesi per questo percorso:
            • \(expectedPayloads.isEmpty ? "(nessun POI nel percorso)" : expectedPayloads)
            """
            showQRErrorAlert = true
            return
        }

        // 2. È già stato completato?
        if completedPOIIds.contains(matchedPOI.id) {
            qrErrorMessage = "Hai già visitato \"\(matchedPOI.name)\". Procedi verso la prossima tappa."
            showQRErrorAlert = true
            return
        }

        // 3. Accetta il POI (anche se fuori ordine)
        completedPOIIds.insert(matchedPOI.id)
        scannedPOI = matchedPOI
        navigationState = .poiReached(matchedPOI)
        showPOIModal = true
    }

    // MARK: - Modal Dismiss Handler

    private func handleModalDismiss() {
        if isCompleted {
            navigationState = .completed
        } else if let next = currentStep {
            navigationState = .navigatingTo(next)
        }
    }
}

// MARK: - Card: Punto di partenza

struct StartPointCard: View {
    let name: String
    let description: String
    let nextStepInstructions: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color("WWFGreen"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sei qui: \(name)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            if let instructions = nextStepInstructions {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundColor(Color("WWFGreen"))
                        .font(.caption)
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .background(Color("WWFGreen").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Card: In navigazione

struct NavigatingCard: View {
    let step: TrailStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let poi = step.poi {
                        Text("Dirigiti verso: \(poi.name)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Text("Scansiona il QR code quando arrivi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.turn.up.right")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .padding(.top, 2)
                Text(step.instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Card: POI raggiunto

struct POIReachedCard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Raggiunto: \(poi.name)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("Visualizza le informazioni nel pannello")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Marker punto di partenza (legacy — kept for reference but VisitorMapView uses UIKit markers)

struct StartPointMarker: View {
    let name: String
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isCurrent {
                    Circle()
                        .fill(Color("WWFGreen").opacity(0.25))
                        .frame(width: 44, height: 44)
                }
                Circle()
                    .fill(Color("WWFGreen"))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
                    .shadow(radius: 3)
            }
            Text(name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Indicatore posizione utente (legacy — kept for reference)

struct UserLocationIndicator: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0 : 0.6)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 3)
        }
        .onAppear { pulse = true }
    }
}
