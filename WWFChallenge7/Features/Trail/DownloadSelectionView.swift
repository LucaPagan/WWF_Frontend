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
    private var selectedLanguage: String { LocalizationManager.shared.preferredLanguage }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(localizer.localizedString(for: "prepare_trail"))
                            .font(WWFDesign.Typography.largeTitleRounded)
                            .foregroundColor(WWFDesign.Colors.forestDark)
                        Text(localizer.localizedString(for: "download_offline_desc"))
                            .font(WWFDesign.Typography.trailDescBody)
                            .foregroundColor(WWFDesign.Colors.forestDark.opacity(0.70))
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding(.top, 24)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)

                    // Tier Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text(localizer.localizedString(for: "choose_how_much_download"))
                            .font(WWFDesign.Typography.titleRounded)
                            .foregroundColor(WWFDesign.Colors.forestDark)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        VStack(spacing: 16) {
                            ForEach(ContentTier.allCases, id: \.self) { tier in
                                TierSelectionRow(
                                    tier: tier,
                                    isSelected: selectedTier == tier,
                                    isDownloaded: isTierUsableOffline(tier),
                                    needsUpdate: package(for: tier)?.needsUpdate == true,
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
                        let isCurrentTierDownloaded = isTierUsableOffline(selectedTier)
                        let selectedNeedsUpdate = package(for: selectedTier)?.needsUpdate == true
                        let packageAvailable = package(for: selectedTier) != nil

                        if let error = downloadManager.error {
                            Text(error)
                                .font(WWFDesign.Typography.trailDesc)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        } else if !packageAvailable && !isCurrentTierDownloaded {
                            Text(LocalizationManager.shared.localizedString(for: "offline_bundle_unavailable"))
                                .font(WWFDesign.Typography.trailDesc)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            if isCurrentTierDownloaded && !selectedNeedsUpdate {
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
                                Image(systemName: isCurrentTierDownloaded && !selectedNeedsUpdate ? "play.fill" : "icloud.and.arrow.down.fill")
                                Text(buttonTitle(isDownloaded: isCurrentTierDownloaded, needsUpdate: selectedNeedsUpdate))
                                    .fontWeight(.bold)
                                    .font(WWFDesign.Typography.trailName)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(WWFDesign.Colors.forestMid)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.22), lineWidth: 1))
                            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.09), radius: 8, x: 0, y: 3)
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
        .background(WWFDesign.Colors.backgroundCream.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(WWFDesign.Colors.forestDark.opacity(0.72))
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

        private func isTierUsableOffline(_ tier: ContentTier) -> Bool {
            let trailId = trail.id
            let descriptor = FetchDescriptor<DownloadPackage>(
                predicate: #Predicate<DownloadPackage> { $0.pathId == trailId && $0.isReady == true }
            )
            let packages = (try? modelContext.fetch(descriptor)) ?? []
            return packages.contains { package in
                package.tier.includes(tier) && package.isDownloaded
            }
        }

        private func buttonTitle(isDownloaded: Bool, needsUpdate: Bool) -> String {
            if isDownloaded && needsUpdate {
                return localizer.localizedString(for: "update_downloaded_bundle")
            }
            return isDownloaded ? localizer.localizedString(for: "use_this_version") : localizer.localizedString(for: "download_and_start")
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
    let needsUpdate: Bool
    let onSelect: () -> Void
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    OrganicBlobShape(variant: tierBlobVariant)
                        .fill(isSelected ? WWFDesign.Colors.forestMid : WWFDesign.Colors.easyFill)
                        .frame(width: 44, height: 44)
                        .overlay(
                            OrganicBlobShape(variant: tierBlobVariant)
                                .stroke(WWFDesign.Colors.organicOutline.opacity(isSelected ? 0.30 : 0.18), lineWidth: 1)
                        )
                    Image(systemName: tierIcon)
                        .font(WWFDesign.Typography.body)
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
                    
                    if needsUpdate {
                        Text(localizer.localizedString(for: "update_available_chip"))
                            .font(WWFDesign.Typography.caption.weight(.bold))
                            .foregroundColor(WWFDesign.Colors.warningText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WWFDesign.Colors.warningFill)
                            .clipShape(Capsule())
                    } else if isDownloaded {
                        Text(localizer.localizedString(for: "downloaded_chip"))
                            .font(WWFDesign.Typography.caption.weight(.bold))
                            .foregroundColor(WWFDesign.Colors.easyText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WWFDesign.Colors.easyFill)
                            .clipShape(Capsule())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(WWFDesign.Typography.body)
                            .foregroundColor(WWFDesign.Colors.forestMid)
                    }
                }
            }
            .padding()
            .background(WWFDesign.Colors.cardCream)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WWFDesign.Colors.organicOutline.opacity(isSelected ? 0.34 : 0.18), lineWidth: isSelected ? 1.3 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(WWFDesign.Colors.organicInset.opacity(0.62), lineWidth: 1)
                    .padding(4)
            )
            .shadow(color: WWFDesign.Colors.forestDark.opacity(isSelected ? 0.09 : 0.05), radius: 7, x: 0, y: 3)
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

    private var tierBlobVariant: Int {
        switch tier {
        case .light: return 0
        case .standard: return 1
        case .full: return 2
        }
    }
}
