//
//  AccessibilitySettingsView.swift
//  WWFChallenge7
//
//  Accessibility preferences panel reachable from Dashboard in ≤ 2 taps.
//  All toggles have VoiceOver labels and hints.
//  Preferences persist offline via @AppStorage.
//

import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject var prefs: AccessibilityPreferences
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        Form {
            // MARK: - Text & Reading
            Section {
                Toggle(isOn: $prefs.easyReadMode) {
                    Label(localizer.localizedString(for: "easy_read_label"), systemImage: "text.badge.checkmark")
                        .font(WWFDesign.Typography.bodyLargeRounded)
                }
                .accessibilityLabel(localizer.localizedString(for: "easy_read_accessibility_label"))
                .accessibilityHint(localizer.localizedString(for: "easy_read_accessibility_hint"))

                Toggle(isOn: $prefs.kidsMode) {
                    Label(localizer.localizedString(for: "kids_mode_label"), systemImage: "figure.and.child.holdinghands")
                        .font(WWFDesign.Typography.bodyLargeRounded)
                }
                .accessibilityLabel(localizer.localizedString(for: "kids_mode_label"))
                .accessibilityHint(localizer.localizedString(for: "kids_mode_accessibility_hint"))
            } header: {
                Text(localizer.localizedString(for: "text_and_reading"))
            } footer: {
                Text(localizer.localizedString(for: "simplified_text_desc"))
            }

            // MARK: - Navigation
            Section {
                Toggle(isOn: $prefs.preferListView) {
                    Label(localizer.localizedString(for: "default_list_view"), systemImage: "list.bullet")
                        .font(WWFDesign.Typography.bodyLargeRounded)
                }
                .accessibilityLabel(localizer.localizedString(for: "default_list_view"))
                .accessibilityHint(localizer.localizedString(for: "default_list_view_hint"))
            } header: {
                Text(localizer.localizedString(for: "navigation_label"))
            } footer: {
                Text(localizer.localizedString(for: "list_view_desc"))
            }

            // MARK: - Audio & Feedback
            Section {
                Toggle(isOn: $prefs.autoAudio) {
                    Label(localizer.localizedString(for: "auto_audio_qr"), systemImage: "speaker.wave.2")
                        .font(WWFDesign.Typography.bodyLargeRounded)
                }
                .accessibilityLabel(localizer.localizedString(for: "auto_audio_qr"))
                .accessibilityHint(localizer.localizedString(for: "auto_audio_qr_hint"))

                Toggle(isOn: $prefs.hapticFeedback) {
                    Label(localizer.localizedString(for: "recognition_haptics"), systemImage: "iphone.radiowaves.left.and.right")
                        .font(WWFDesign.Typography.bodyLargeRounded)
                }
                .accessibilityLabel(localizer.localizedString(for: "recognition_haptics"))
                .accessibilityHint(localizer.localizedString(for: "recognition_haptics_hint"))
            } header: {
                Text(localizer.localizedString(for: "audio_feedback"))
            }

            // MARK: - Info
            Section {
                HStack {
                    Image(systemName: "accessibility")
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.localizedString(for: "system_accessibility"))
                            .font(WWFDesign.Typography.bodyLargeRounded.weight(.semibold))
                        Text(localizer.localizedString(for: "system_accessibility_desc"))
                            .font(WWFDesign.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(localizer.localizedString(for: "system_accessibility_desc"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(WWFDesign.Colors.backgroundCream)
        .navigationTitle(localizer.localizedString(for: "accessibility"))
        .navigationBarTitleDisplayMode(.large)
    }
}
