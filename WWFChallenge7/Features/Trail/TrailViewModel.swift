//
//  TrailViewModel.swift
//  WWFChallenge7
//
//  ViewModel for ActiveTrailView — manages trail navigation state,
//  QR scan handling, and position tracking.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class TrailViewModel: ObservableObject {

    // MARK: - Published State

    @Published var completedPOIIds: Set<UUID> = []
    @Published var navigationState: TrailNavigationState = .atStart
    @Published var showScanner: Bool = false
    @Published var showPOIModal: Bool = false
    @Published var scannedPOI: POI?
    @Published var showQRErrorAlert: Bool = false
    @Published var qrErrorMessage: String = ""

    let trail: Trail

    init(trail: Trail) {
        self.trail = trail
    }

    // MARK: - Computed

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

    // MARK: - Actions

    func startTrail() {
        if let first = trail.sortedSteps.first {
            navigationState = .navigatingTo(first)
        }
    }

    func openScanner() {
        showScanner = true
    }

    func handleQRScan(payload: String) {
        showScanner = false

        let cleanPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trail.isActive else {
            qrErrorMessage = "Questo percorso non è attivo. Contatta il gestore dell'oasi."
            showQRErrorAlert = true
            return
        }

        let allPOIs = trail.sortedSteps.compactMap { $0.poi }

        guard let matchedPOI = allPOIs.first(where: { $0.qrPayload == cleanPayload }) else {
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

        if completedPOIIds.contains(matchedPOI.id) {
            qrErrorMessage = "Hai già visitato \"\(matchedPOI.name)\". Procedi verso la prossima tappa."
            showQRErrorAlert = true
            return
        }

        completedPOIIds.insert(matchedPOI.id)
        scannedPOI = matchedPOI
        navigationState = .poiReached(matchedPOI)
        showPOIModal = true
    }

    func handleModalDismiss() {
        if isCompleted {
            navigationState = .completed
        } else if let next = currentStep {
            navigationState = .navigatingTo(next)
        }
    }
}
