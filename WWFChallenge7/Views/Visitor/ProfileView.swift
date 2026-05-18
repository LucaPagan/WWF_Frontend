//
//  ProfileView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import Combine

struct ProfileView: View {
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("preferredLanguage") private var language = "it"
    @AppStorage("largeText") private var largeText = false
    @AppStorage("simplifiedMode") private var simplifiedMode = false
    @AppStorage("notificationsEnabled") private var notifications = true

    var body: some View {
        NavigationStack {
            Form {
                Section(localizer.localizedString(for: "language")) {
                    Picker(localizer.localizedString(for: "language"), selection: Binding(
                        get: { language },
                        set: { newValue in
                            language = newValue
                            localizer.preferredLanguage = newValue
                            localizer.objectWillChange.send()
                        }
                    )) {
                        Text("🇮🇹 It").tag("it")
                        Text("🇬🇧 En").tag("en")
                        Text("🇩🇪 De").tag("de")
                        Text("🇫🇷 Fr").tag("fr")
                    }
                    .pickerStyle(.segmented)
                }

                Section(localizer.localizedString(for: "accessibility")) {
                    Toggle(localizer.localizedString(for: "large_text"), isOn: $largeText)
                        .tint(WWFStyle.Colors.green)
                    Toggle(localizer.localizedString(for: "simplified_mode"), isOn: $simplifiedMode)
                        .tint(WWFStyle.Colors.green)
                }

                Section(localizer.localizedString(for: "notifications")) {
                    Toggle(localizer.localizedString(for: "oasis_updates"), isOn: $notifications)
                        .tint(WWFStyle.Colors.green)
                }

                Section(localizer.localizedString(for: "info")) {
                    LabeledContent(localizer.localizedString(for: "version"), value: "1.0.0")
                    LabeledContent("Oasis", value: localizer.localizedString(for: "oasis_val"))
                    Link(destination: URL(string: "https://www.wwf.it")!) {
                        Label(localizer.localizedString(for: "wwf_website"), systemImage: "globe")
                            .foregroundColor(WWFStyle.Colors.green)
                    }
                }
            }
            .navigationTitle(localizer.localizedString(for: "settings"))
        }
    }
}
