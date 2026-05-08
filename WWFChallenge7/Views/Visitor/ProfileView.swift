//
//  ProfileView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

struct ProfileView: View {
    @AppStorage("preferredLanguage") private var language = "it"
    @AppStorage("largeText") private var largeText = false
    @AppStorage("simplifiedMode") private var simplifiedMode = false
    @AppStorage("notificationsEnabled") private var notifications = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Lingua") {
                    Picker("Lingua app", selection: $language) {
                        Text("🇮🇹 Italiano").tag("it")
                        Text("🇬🇧 English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Accessibilità") {
                    Toggle("Testo grande", isOn: $largeText)
                        .tint(Color("WWFGreen"))
                    Toggle("Modalità semplificata", isOn: $simplifiedMode)
                        .tint(Color("WWFGreen"))
                }

                Section("Notifiche") {
                    Toggle("Aggiornamenti Oasi", isOn: $notifications)
                        .tint(Color("WWFGreen"))
                }

                Section("Informazioni") {
                    LabeledContent("Versione", value: "1.0.0")
                    LabeledContent("Oasi", value: "Astroni · Napoli")
                    Link(destination: URL(string: "https://www.wwf.it")!) {
                        Label("Sito WWF Italia", systemImage: "globe")
                            .foregroundColor(Color("WWFGreen"))
                    }
                }
            }
            .navigationTitle("Profilo")
        }
    }
}