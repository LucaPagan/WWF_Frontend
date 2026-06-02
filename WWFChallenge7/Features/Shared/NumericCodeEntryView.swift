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
    @ObservedObject private var localizer = LocalizationManager.shared
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
                Text(localizer.localizedString(for: "enter_poi_code"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Subtitle
                Text(localizer.localizedString(for: "poi_code_hint"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Code input field
                TextField(localizer.localizedString(for: "six_digit_code"), text: $code)
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
                    .accessibilityLabel(localizer.localizedString(for: "poi_numeric_code"))
                    .accessibilityHint(localizer.localizedString(for: "poi_code_accessibility_hint"))

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
                    .accessibilityLabel("\(localizer.localizedString(for: "error_prefix")): \(error)")
                }

                // Confirm button
                Button(action: lookupCode) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        Text(localizer.localizedString(for: "confirm_button"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(code.count != 6 || isLoading)
                .padding(.horizontal, 32)
                .accessibilityLabel(localizer.localizedString(for: "code_confirmation_accessibility"))
                .accessibilityHint(localizer.localizedString(for: "code_confirmation_hint"))

                Spacer()
            }
            .navigationTitle(localizer.localizedString(for: "manual_code_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.localizedString(for: "close")) { dismiss() }
                        .accessibilityLabel(localizer.localizedString(for: "close_code_entry"))
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
                    argument: "\(localizer.localizedString(for: "poi_found_announcement")): \(poi.localizedName)")
                onPOIFound(poi)
                dismiss()
            } else {
                errorMessage = localizer.localizedString(for: "invalid_code_for_trail")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            errorMessage = "\(localizer.localizedString(for: "lookup_error")): \(error.localizedDescription)"
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
