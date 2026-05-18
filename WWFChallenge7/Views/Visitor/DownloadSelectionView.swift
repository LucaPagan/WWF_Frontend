//
//  DownloadSelectionView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 16/05/26.
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
                    .font(.title2)
                    .fontWeight(.bold)
                Text(localizer.localizedString(for: "download_offline_desc"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal)
            
            // Language Selection
            VStack(alignment: .leading, spacing: 12) {
                Text(localizer.localizedString(for: "content_language"))
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(languages, id: \.0) { lang in
                            Button {
                                selectedLanguage = lang.0
                            } label: {
                                HStack {
                                    Text(lang.2)
                                    Text(lang.1)
                                }
                               .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedLanguage == lang.0 ? WWFStyle.Colors.green.opacity(0.1) : Color.gray.opacity(0.1))
                                .foregroundColor(selectedLanguage == lang.0 ? WWFStyle.Colors.green : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedLanguage == lang.0 ? WWFStyle.Colors.green : Color.clear, lineWidth: 1)
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
                    .font(.headline)
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
                            .tint(WWFStyle.Colors.green)
                        Text(downloadManager.currentDownloadName ?? localizer.localizedString(for: "downloading_progress"))
                            .font(.caption)
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(WWFStyle.Colors.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: WWFStyle.Colors.green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                
                Button(localizer.localizedString(for: "cancel")) {
                    dismiss()
                }
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
        // Find or create a DownloadPackage record in local SwiftData context
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
                        .fill(isSelected ? WWFStyle.Colors.green : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: tierIcon)
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.localizedString(for: "tier_" + tier.rawValue))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(localizer.localizedString(for: "tier_" + tier.rawValue + "_desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(tier.sizeLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(WWFStyle.Colors.green)
                    
                    if isDownloaded {
                        Text(localizer.localizedString(for: "downloaded_chip"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(WWFStyle.Colors.green)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? WWFStyle.Colors.green : Color.clear, lineWidth: 2)
            )
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
