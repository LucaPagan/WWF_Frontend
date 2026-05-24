//
//  DownloadSelectionView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 16/05/26.
//  Redesigned — Maggio 2026
//

import SwiftUI
import SwiftData

struct DownloadSelectionView: View {
    let trail: Trail
    var onDownloadComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizer = LocalizationManager.shared
    
    @State private var selectedTier: ContentTier = .light
    @State private var selectedLanguage: String = LocalizationManager.shared.preferredLanguage
    @State private var showLanguagePicker = false
    
    let languages = [
        ("it", "Italiano", "🇮🇹"),
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪"),
        ("fr", "Français", "🇫🇷")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator (simulated for better spacing)
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(localizer.localizedString(for: "prepare_trail"))
                            .font(Font.custom("Georgia", size: 24, relativeTo: .title).weight(.bold))
                            .foregroundColor(WWFDesign.Colors.forestDark)
                        Text(localizer.localizedString(for: "download_offline_desc"))
                            .font(WWFDesign.Typography.trailDesc)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    
                    // Language Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text(localizer.localizedString(for: "content_language"))
                            .font(WWFDesign.Typography.trailName)
                            .foregroundColor(WWFDesign.Colors.forestDark)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(languages, id: \.0) { lang in
                                    Button {
                                        selectedLanguage = lang.0
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(lang.2)
                                                .accessibilityHidden(true)
                                            Text(lang.1)
                                                .font(WWFDesign.Typography.metaLabel)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(selectedLanguage == lang.0 ? WWFDesign.Colors.easyFill : Color.gray.opacity(0.08))
                                        .foregroundColor(selectedLanguage == lang.0 ? WWFDesign.Colors.easyText : .primary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedLanguage == lang.0 ? WWFDesign.Colors.forestLight.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .accessibilityLabel("Lingua \(lang.1)")
                                    .accessibilityAddTraits(selectedLanguage == lang.0 ? [.isSelected] : [])
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 24)
                    
                    // Tier Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text(localizer.localizedString(for: "choose_how_much_download"))
                            .font(WWFDesign.Typography.trailName)
                            .foregroundColor(WWFDesign.Colors.forestDark)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            ForEach(ContentTier.allCases, id: \.self) { tier in
                                TierSelectionRow(
                                    tier: tier,
                                    isSelected: selectedTier == tier,
                                    isDownloaded: downloadedTiers.contains(tier),
                                    onSelect: { selectedTier = tier }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Action Button
                VStack(spacing: 16) {
                    if downloadManager.isDownloading {
                        VStack(spacing: 12) {
                            ProgressView(value: downloadManager.progress)
                                .tint(WWFDesign.Colors.forestLight)
                            Text(downloadManager.currentDownloadName ?? localizer.localizedString(for: "downloading_progress"))
                                .font(WWFDesign.Typography.trailDesc)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        let isCurrentTierDownloaded = downloadedTiers.contains(selectedTier)
                        let packageAvailable = package(for: selectedTier) != nil

                        if let error = downloadManager.error {
                            Text(error)
                                .font(WWFDesign.Typography.trailDesc)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        } else if !packageAvailable && !isCurrentTierDownloaded {
                            Text("Bundle offline non ancora disponibile. Riprova dopo la sincronizzazione.")
                                .font(WWFDesign.Typography.trailDesc)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            if isCurrentTierDownloaded {
                                onDownloadComplete?()
                                if onDownloadComplete == nil {
                                    dismiss()
                                }
                            } else {
                                Task {
                                    await startDownload()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: isCurrentTierDownloaded ? "play.fill" : "icloud.and.arrow.down.fill")
                                Text(isCurrentTierDownloaded ? localizer.localizedString(for: "use_this_version") : localizer.localizedString(for: "download_and_start"))
                                    .fontWeight(.bold)
                                    .font(WWFDesign.Typography.trailName)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(WWFDesign.Colors.forestMid)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: WWFDesign.Colors.forestMid.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .opacity(!isCurrentTierDownloaded && !packageAvailable ? 0.75 : 1)
                        .accessibilityLabel(isCurrentTierDownloaded ? "Usa questa versione e inizia" : "Scarica e inizia")
                        .accessibilityHint(packageAvailable || isCurrentTierDownloaded ? "Avvia il percorso con il livello di download selezionato" : "Verifica se il bundle offline e disponibile")
                    }
                    
                    Button(localizer.localizedString(for: "cancel")) {
                        dismiss()
                    }
                    .font(WWFDesign.Typography.trailName)
                    .foregroundColor(.secondary)
                    .frame(minHeight: 44)
                    .padding(.bottom, 8)
                    .accessibilityLabel("Annulla")
                    .accessibilityHint("Chiudi senza scaricare")
                }
                .padding(24)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.secondary.opacity(0.7))
                    .padding(16)
                    .background(Color.white.opacity(0.001)) // Increase touch target
            }
            .accessibilityLabel("Chiudi schermata")
        }
    }
        
    private var downloadedTiers: Set<ContentTier> {
            let trailId = trail.id
            let descriptor = FetchDescriptor<DownloadPackage>(
                predicate: #Predicate<DownloadPackage> { $0.pathId == trailId && $0.isReady == true }
            )
            let packages = (try? modelContext.fetch(descriptor)) ?? []
            return Set(packages.filter { $0.isDownloaded }.map { $0.tier })
        }
        
        
        private func startDownload() async {
            downloadManager.error = nil

            var pkg = package(for: selectedTier)
            if pkg == nil {
                await syncManager.pullLatestData()
                pkg = package(for: selectedTier)
            }

            guard let pkg else {
                downloadManager.error = "Bundle offline non disponibile per questo livello."
                return
            }
            
            await downloadManager.downloadPackage(pkg, language: selectedLanguage)
            
            if downloadManager.error == nil {
                onDownloadComplete?()
                if onDownloadComplete == nil {
                    dismiss()
                }
            }
        }

        private func package(for tier: ContentTier) -> DownloadPackage? {
            let tierRaw = tier.rawValue
            let trailId = trail.id
            let descriptor = FetchDescriptor<DownloadPackage>(
                predicate: #Predicate<DownloadPackage> {
                    $0.pathId == trailId &&
                    $0.tierRawValue == tierRaw &&
                    $0.isReady == true &&
                    $0.generationStatus == "ready"
                }
            )
            return try? modelContext.fetch(descriptor).first
        }
    }

struct TierSelectionRow: View {
    let tier: ContentTier
    let isSelected: Bool
    let isDownloaded: Bool
    let onSelect: () -> Void
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? WWFDesign.Colors.forestMid : Color.gray.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: tierIcon)
                        .font(.body)
                        .foregroundColor(isSelected ? .white : WWFDesign.Colors.forestDark.opacity(0.65))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.localizedString(for: "tier_" + tier.rawValue))
                        .font(WWFDesign.Typography.trailName)
                        .fontWeight(.semibold)
                        .foregroundColor(WWFDesign.Colors.forestDark)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(localizer.localizedString(for: "tier_" + tier.rawValue + "_desc"))
                        .font(WWFDesign.Typography.trailDesc)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(tier.sizeLabel)
                        .font(WWFDesign.Typography.badge)
                        .fontWeight(.bold)
                        .foregroundColor(WWFDesign.Colors.forestLight)
                    
                    if isDownloaded {
                        Text(localizer.localizedString(for: "downloaded_chip"))
                            .font(.caption2.weight(.bold))
                            .foregroundColor(WWFDesign.Colors.easyText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WWFDesign.Colors.easyFill)
                            .clipShape(Capsule())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundColor(WWFDesign.Colors.forestMid)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                    .stroke(isSelected ? WWFDesign.Colors.forestMid : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.04 : 0.01), radius: 4, x: 0, y: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localizer.localizedString(for: "tier_" + tier.rawValue)). \(localizer.localizedString(for: "tier_" + tier.rawValue + "_desc")). \(tier.sizeLabel). \(isDownloaded ? "Già scaricato" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    var tierIcon: String {
        switch tier {
        case .light:    return "doc.text"
        case .standard: return "play.rectangle"
        case .full:     return "arkit"
        }
    }
}
