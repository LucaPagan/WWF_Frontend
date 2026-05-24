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

    var body: some View {
        Form {
            // MARK: - Text & Reading
            Section {
                Toggle(isOn: $prefs.easyReadMode) {
                    Label("Testo semplificato (Easy-to-Read)", systemImage: "text.badge.checkmark")
                }
                .accessibilityLabel("Testo semplificato Easy-to-Read")
                .accessibilityHint("Mostra versioni semplificate dei contenuti dei punti di interesse, con frasi brevi e vocabolario semplice")

                Toggle(isOn: $prefs.kidsMode) {
                    Label("Modalità bambini", systemImage: "figure.and.child.holdinghands")
                }
                .accessibilityLabel("Modalità bambini")
                .accessibilityHint("Mostra solo percorsi adatti ai bambini con icone grandi e linguaggio semplice")
            } header: {
                Text("Testo e Lettura")
            } footer: {
                Text("Il testo semplificato segue le linee guida Easy-to-Read europee per rendere i contenuti accessibili a tutti.")
            }

            // MARK: - Navigation
            Section {
                Toggle(isOn: $prefs.preferListView) {
                    Label("Vista lista come predefinita", systemImage: "list.bullet")
                }
                .accessibilityLabel("Vista lista come predefinita")
                .accessibilityHint("Mostra il percorso come lista di istruzioni testuali invece della mappa visiva")
            } header: {
                Text("Navigazione")
            } footer: {
                Text("La vista lista è consigliata per utenti con lettore di schermo. Si attiva automaticamente quando VoiceOver è attivo.")
            }

            // MARK: - Audio & Feedback
            Section {
                Toggle(isOn: $prefs.autoAudio) {
                    Label("Audio automatico al QR", systemImage: "speaker.wave.2")
                }
                .accessibilityLabel("Avvia audio automaticamente alla scansione QR")
                .accessibilityHint("Quando scansioni un QR code, avvia automaticamente la descrizione audio del punto di interesse")

                Toggle(isOn: $prefs.hapticFeedback) {
                    Label("Vibrazione al riconoscimento", systemImage: "iphone.radiowaves.left.and.right")
                }
                .accessibilityLabel("Vibrazione al riconoscimento QR")
                .accessibilityHint("Attiva una vibrazione quando il QR code viene riconosciuto con successo")
            } header: {
                Text("Audio e Feedback")
            }

            // MARK: - Info
            Section {
                HStack {
                    Image(systemName: "accessibility")
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibilità di sistema")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Per impostazioni avanzate come VoiceOver, Dynamic Type e Aumenta Contrasto, usa Impostazioni > Accessibilità del tuo dispositivo.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Per impostazioni avanzate di accessibilità come VoiceOver e Dynamic Type, vai nelle Impostazioni di sistema del dispositivo, sezione Accessibilità")
            }
        }
        .navigationTitle("Accessibilità")
        .navigationBarTitleDisplayMode(.large)
    }
}
