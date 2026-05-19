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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
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
            // Header
            VStack(spacing: 8) {
                Text(localizer.localizedString(for: "prepare_trail"))
                    .font(Font.custom("Georgia", size: 22).weight(.bold))
                    .foregroundColor(WWFDesign.Colors.forestDark)
                Text(localizer.localizedString(for: "download_offline_desc"))
                    .font(WWFDesign.Typography.trailDesc)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal)
            
            // Language Selection
            VStack(alignment: .leading, spacing: 12) {
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
                                    Text(lang.1)
                                        .font(WWFDesign.Typography.metaLabel)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedLanguage == lang.0 ? WWFDesign.Colors.forestLight.opacity(0.12) : Color.gray.opacity(0.08))
                                .foregroundColor(selectedLanguage == lang.0 ? WWFDesign.Colors.forestDark : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedLanguage == lang.0 ? WWFDesign.Colors.forestLight.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
            
            // Tier Selection
            VStack(alignment: .leading, spacing: 12) {
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
            
            Spacer()
            
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
                    
                    Button {
                        if isCurrentTierDownloaded {
                            dismiss()
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
                }
                
                Button(localizer.localizedString(for: "cancel")) {
                    dismiss()
                }
                .font(WWFDesign.Typography.trailName)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            }
            .padding(24)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
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
        let tierRaw = selectedTier.rawValue
        let trailId = trail.id
        
        let descriptor = FetchDescriptor<DownloadPackage>(
            predicate: #Predicate<DownloadPackage> { $0.pathId == trailId && $0.tierRawValue == tierRaw }
        )
        
        let pkg: DownloadPackage
        if let existing = try? modelContext.fetch(descriptor).first {
            pkg = existing
        } else {
            pkg = DownloadPackage(pathId: trailId, tier: selectedTier, isReady: true)
            modelContext.insert(pkg)
        }
        
        await downloadManager.downloadPackage(pkg, language: selectedLanguage)
        
        if downloadManager.error == nil {
            dismiss()
        }
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
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? WWFDesign.Colors.forestMid : Color.gray.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: tierIcon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .white : WWFDesign.Colors.forestDark.opacity(0.65))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.localizedString(for: "tier_" + tier.rawValue))
                        .font(WWFDesign.Typography.trailName)
                        .fontWeight(.semibold)
                        .foregroundColor(WWFDesign.Colors.forestDark)
                    Text(localizer.localizedString(for: "tier_" + tier.rawValue + "_desc"))
                        .font(WWFDesign.Typography.trailDesc)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(tier.sizeLabel)
                        .font(WWFDesign.Typography.badge)
                        .fontWeight(.bold)
                        .foregroundColor(WWFDesign.Colors.forestLight)
                    
                    if isDownloaded {
                        Text(localizer.localizedString(for: "downloaded_chip"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(WWFDesign.Colors.easyText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WWFDesign.Colors.easyFill)
                            .clipShape(Capsule())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
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
    }
    
    var tierIcon: String {
        switch tier {
        case .light:    return "doc.text"
        case .standard: return "play.rectangle"
        case .full:     return "arkit"
        }
    }
}
