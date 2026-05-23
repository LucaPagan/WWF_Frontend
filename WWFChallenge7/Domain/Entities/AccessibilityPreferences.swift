//
//  AccessibilityPreferences.swift
//  WWFChallenge7
//
//  Global accessibility preferences using @AppStorage for offline persistence.
//  Injected as EnvironmentObject from the app root.
//

import SwiftUI
import Combine

@MainActor
final class AccessibilityPreferences: ObservableObject {

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Published Preferences (persisted via @AppStorage)

    @AppStorage("wwf_easy_read_mode") var easyReadMode: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("wwf_kids_mode") var kidsMode: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("wwf_prefer_list_view") var preferListView: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("wwf_auto_audio") var autoAudio: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("wwf_haptic_feedback") var hapticFeedback: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Computed Helpers

    /// Returns true if VoiceOver is currently active
    var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    /// Returns true if the user has set an accessibility text size
    var isAccessibilityTextSize: Bool {
        UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
    }

    /// Returns the preferred view mode for paths — list if VoiceOver or user preference
    var shouldDefaultToListView: Bool {
        preferListView || isVoiceOverRunning
    }

    // MARK: - Haptic Feedback

    func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard hapticFeedback else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func triggerNotificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticFeedback else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
