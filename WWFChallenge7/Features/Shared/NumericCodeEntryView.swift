//
//  NumericCodeEntryView.swift
//  WWFChallenge7
//
//  Fallback for QR scanning — manual 6-digit numeric code entry.
//  Supports users with motor difficulties who can't hold the phone steady for QR scan.
//  Works offline via local SwiftData lookup.
//

import SwiftUI
import SwiftData

struct NumericCodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    var allowedPOIIds: Set<UUID>? = nil
    var allowGlobalAlerts: Bool = true
    var onPOIFound: (POI) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "number.circle.fill")
                    .font(.system(.largeTitle))
                    .foregroundColor(.green)
                    .accessibilityHidden(true)

                // Title
                Text("Inserisci il codice del punto di interesse")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Subtitle
                Text("Il codice a 6 cifre è visibile sotto il QR code del POI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Code input field
                TextField("Codice a 6 cifre", text: $code)
                    .keyboardType(.numberPad)
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .frame(height: 56)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    .onChange(of: code) { _, newValue in
                        // Limit to 6 digits
                        code = String(newValue.prefix(6).filter { $0.isNumber })
                        errorMessage = nil
                    }
                    .accessibilityLabel("Codice numerico POI")
                    .accessibilityHint("Inserisci il codice a 6 cifre presente sotto il QR code")

                // Error message
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Errore: \(error)")
                }

                // Confirm button
                Button(action: lookupCode) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        Text("Conferma")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(code.count != 6 || isLoading)
                .padding(.horizontal, 32)
                .accessibilityLabel("Conferma codice")
                .accessibilityHint("Cerca il punto di interesse con il codice inserito")

                Spacer()
            }
            .navigationTitle("Codice Manuale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                        .accessibilityLabel("Chiudi inserimento codice")
                }
            }
        }
    }

    private func lookupCode() {
        isLoading = true
        errorMessage = nil

        // Local SwiftData lookup — works offline
        let searchCode = code
        let descriptor = FetchDescriptor<POI>(predicate: #Predicate { poi in
            poi.numericCode == searchCode
        })

        do {
            let results = try modelContext.fetch(descriptor)
            if let poi = results.first, isAllowed(poi) {
                // Haptic success
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                // VoiceOver announcement
                UIAccessibility.post(notification: .announcement,
                    argument: "POI trovato: \(poi.localizedName)")
                onPOIFound(poi)
                dismiss()
            } else {
                errorMessage = "Codice non valido per questo percorso"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            errorMessage = "Errore nella ricerca: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func isAllowed(_ poi: POI) -> Bool {
        if let allowedPOIIds, allowedPOIIds.contains(poi.id) {
            return true
        }
        if allowGlobalAlerts, poi.type.isGlobalAlertType {
            return true
        }
        return allowedPOIIds == nil
    }
}
