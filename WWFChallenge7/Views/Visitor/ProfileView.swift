//
//  ProfileView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//  Redesigned — Maggio 2026
//

import SwiftUI
import Combine

struct ProfileView: View {
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("preferredLanguage") private var language = "it"
    @EnvironmentObject var accessibilityPreferences: AccessibilityPreferences
    @AppStorage("notificationsEnabled") private var notifications = true

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Premium Obsidian Slate Banner Header
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: WWFDesign.Radius.hero)
                            .fill(Color(red: 0.086, green: 0.122, blue: 0.165))
                            .frame(height: 190)

                        // Pattern organico — cerchi sfumati minerali/ossidiana
                        GeometryReader { geo in
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.153, green: 0.224, blue: 0.314))
                                    .frame(width: 200, height: 200)
                                    .blur(radius: 50)
                                    .offset(x: geo.size.width * 0.6, y: -30)
                                    .opacity(0.6)

                                Circle()
                                    .fill(Color(red: 0.251, green: 0.380, blue: 0.522))
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 40)
                                    .offset(x: geo.size.width * 0.75, y: 60)
                                    .opacity(0.25)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.hero))

                        // Icona ingranaggio configurazione decorativa in alto a destra
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 115))
                            .foregroundColor(Color(red: 0.647, green: 0.784, blue: 0.922).opacity(0.06))
                            .rotationEffect(.degrees(15))
                            .offset(x: UIScreen.main.bounds.width - 180, y: -20)
                            .accessibilityHidden(true)

                        // Contenuto
                        VStack(alignment: .leading, spacing: 8) {
                            // Badge impostazioni
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(red: 0.647, green: 0.784, blue: 0.922))
                                    .frame(width: 6, height: 6)
                                Text(localizer.localizedString(for: "settings").uppercased())
                                    .font(WWFDesign.Typography.badge)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.745, green: 0.851, blue: 0.949))
                                    .tracking(1.0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.251, green: 0.380, blue: 0.522).opacity(0.18))
                            .overlay(
                                Capsule().stroke(Color(red: 0.251, green: 0.380, blue: 0.522).opacity(0.35), lineWidth: 0.5)
                            )
                            .clipShape(Capsule())

                            Spacer()

                            Text(localizer.localizedString(for: "profile"))
                                .font(WWFDesign.Typography.heroTitle)
                                .foregroundColor(.white)
                        }
                        .padding(20)
                        .frame(height: 190, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    VStack(spacing: 16) {
                        
                        // SECTION: Language Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizer.localizedString(for: "language"))
                                .font(WWFDesign.Typography.sectionTitle)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                            
                            VStack {
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
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                        
                        // SECTION: Accessibility
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizer.localizedString(for: "accessibility"))
                                .font(WWFDesign.Typography.sectionTitle)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                            
                            VStack(spacing: 12) {
                                Toggle(localizer.localizedString(for: "large_text"), isOn: $accessibilityPreferences.preferListView)
                                    .tint(WWFDesign.Colors.forestMid)
                                    .font(WWFDesign.Typography.trailName)
                                    .accessibilityLabel(localizer.localizedString(for: "large_text"))
                                    .accessibilityHint("Aumenta la dimensione del testo nell'app")
                                
                                Divider()
                                
                                Toggle(localizer.localizedString(for: "simplified_mode"), isOn: $accessibilityPreferences.easyReadMode)
                                    .tint(WWFDesign.Colors.forestMid)
                                    .font(WWFDesign.Typography.trailName)
                                    .accessibilityLabel(localizer.localizedString(for: "simplified_mode"))
                                    .accessibilityHint("Mostra una versione semplificata dell'interfaccia")
                                
                                Divider()
                                
                                NavigationLink {
                                    AccessibilitySettingsView()
                                } label: {
                                    HStack {
                                        Label("Impostazioni accessibilità avanzate", systemImage: "accessibility")
                                            .font(WWFDesign.Typography.trailName)
                                            .foregroundColor(WWFDesign.Colors.forestMid)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .accessibilityLabel("Impostazioni accessibilità avanzate")
                                .accessibilityHint("Apri le impostazioni per testo semplificato, audio automatico e preferenze di navigazione")
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                        
                        // SECTION: Notifications
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizer.localizedString(for: "notifications"))
                                .font(WWFDesign.Typography.sectionTitle)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                            
                            VStack {
                                Toggle(localizer.localizedString(for: "oasis_updates"), isOn: $notifications)
                                    .tint(WWFDesign.Colors.forestMid)
                                    .font(WWFDesign.Typography.trailName)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                        
                        // SECTION: Info & WWF
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizer.localizedString(for: "info"))
                                .font(WWFDesign.Typography.sectionTitle)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                            
                            VStack(spacing: 12) {
                                LabeledContent(localizer.localizedString(for: "version"), value: "1.0.0")
                                    .font(WWFDesign.Typography.trailName)
                                
                                Divider()
                                
                                LabeledContent("Oasis", value: localizer.localizedString(for: "oasis_val"))
                                    .font(WWFDesign.Typography.trailName)
                                
                                Divider()
                                
                                Link(destination: URL(string: "https://www.wwf.it")!) {
                                    HStack {
                                        Label(localizer.localizedString(for: "wwf_website"), systemImage: "globe")
                                            .font(WWFDesign.Typography.trailName)
                                            .foregroundColor(WWFDesign.Colors.forestMid)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundColor(WWFDesign.Colors.forestMid)
                                    }
                                }
                                .accessibilityLabel("Sito web WWF Italia")
                                .accessibilityHint("Apre il sito wwf.it nel browser")
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 32)
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
