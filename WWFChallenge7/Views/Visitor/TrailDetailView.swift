//
//  TrailDetailView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

struct TrailDetailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss
    @State private var startTrail = false
    @State private var showDownloadOptions = false
    @State private var isManagingPackages = false
    @EnvironmentObject var downloadManager: DownloadManager
    @ObservedObject private var localizer = LocalizationManager.shared

    var difficulty: TrailDifficulty {
        trail.difficulty ?? .easy
    }

    var difficultyColor: Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Hero
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    colors: [WWFStyle.Colors.green, WWFStyle.Colors.darkGreen],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 200)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(trail.localizedName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            HStack {
                                Label(localizer.localizedString(for: "difficulty_" + difficulty.rawValue), systemImage: difficulty.icon)
                                    .foregroundColor(difficultyColor)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())

                                Label("\(trail.estimatedMinutes ?? 60) min", systemImage: "clock")
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizer.localizedString(for: "description"))
                            .font(.headline)
                        Text(trail.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Trail Steps
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizer.localizedString(for: "trail_steps"))
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(trail.sortedSteps.indices, id: \.self) { index in
                            let step = trail.sortedSteps[index]
                            TrailStepRowView(
                                step: step,
                                index: index,
                                isLast: index == trail.sortedSteps.count - 1
                            )
                            .padding(.horizontal)
                        }
                    }

                    // Offline Mode Notice
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizer.localizedString(for: "offline_mode"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(localizer.localizedString(for: "offline_navigation_desc"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // CTA
                    let packages = downloadManager.packages(forTrailId: trail.id)
                    let isDownloaded = packages.contains(where: { $0.isDownloaded })
                    
                    if isDownloaded {
                        VStack(spacing: 12) {
                            Button {
                                isManagingPackages = false
                                startTrail = true
                            } label: {
                                Label(localizer.localizedString(for: "continue_offline"), systemImage: "play.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(WWFStyle.Colors.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            
                            Button {
                                isManagingPackages = true
                                showDownloadOptions = true
                            } label: {
                                Label(localizer.localizedString(for: "manage_packages"), systemImage: "arrow.down.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(WWFStyle.Colors.green)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(WWFStyle.Colors.green.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(WWFStyle.Colors.green, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    } else {
                        Button {
                            isManagingPackages = false
                            showDownloadOptions = true
                        } label: {
                            Label(localizer.localizedString(for: "download_and_start"), systemImage: "icloud.and.arrow.down.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(WWFStyle.Colors.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, Color.white.opacity(0.3))
                            .font(.title3)
                    }
                }
            }
            .fullScreenCover(isPresented: $startTrail) {
                ActiveTrailView(trail: trail)
            }
            .sheet(isPresented: $showDownloadOptions) {
                DownloadSelectionView(trail: trail)
                    .onDisappear {
                        if !isManagingPackages {
                            startTrail = true
                        }
                    }
            }
        }
    }
}

// MARK: - Step Row

struct TrailStepRowView: View {
    let step: TrailStep
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(WWFStyle.Colors.green)
                        .frame(width: 30, height: 30)
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(WWFStyle.Colors.green.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let poi = step.poi {
                    Text(poi.localizedName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(step.instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, isLast ? 0 : 20)
            }
            Spacer()
        }
    }
}
