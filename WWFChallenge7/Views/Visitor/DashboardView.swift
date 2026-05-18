//
//  DashboardView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(filter: #Predicate<Trail> { $0.isActive == true })
    private var trails: [Trail]

    @State private var selectedTrail: Trail? = nil
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header Oasi
                    OasiHeaderView()

                    // Info pratiche rapide
                    QuickInfoBanner()

                    // Percorsi disponibili
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizer.localizedString(for: "active_trails"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if trails.isEmpty {
                            ContentUnavailableView(
                                localizer.localizedString(for: "no_active_trails"),
                                systemImage: "map",
                                description: Text(localizer.localizedString(for: "no_active_trails_desc"))
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(trails) { trail in
                                TrailCardView(trail: trail)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        selectedTrail = trail
                                    }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle(localizer.localizedString(for: "app_title"))
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $selectedTrail) { trail in
                TrailDetailView(trail: trail)
            }
        }
    }
}

// MARK: - Header

struct OasiHeaderView: View {
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Immagine di copertina placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [WWFStyle.Colors.green.opacity(0.8), WWFStyle.Colors.darkGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)

                VStack(spacing: 8) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))
                    Text(localizer.localizedString(for: "welcome"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(localizer.localizedString(for: "oasis_val"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Quick Info Banner

struct QuickInfoBanner: View {
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickInfoChip(icon: "clock.fill", text: "9:00 – 17:00", color: .blue)
                QuickInfoChip(icon: "eurosign.circle.fill", text: localizer.localizedString(for: "free_entrance"), color: .green)
                QuickInfoChip(icon: "wifi.slash", text: localizer.localizedString(for: "offline_ready"), color: .orange)
                QuickInfoChip(icon: "qrcode.viewfinder", text: localizer.localizedString(for: "qr_required"), color: .purple)
            }
            .padding(.horizontal)
        }
    }
}

struct QuickInfoChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Trail Card

struct TrailCardView: View {
    let trail: Trail
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trail.localizedName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(trail.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                // Difficoltà
                Label(localizer.localizedString(for: "difficulty_" + difficulty.rawValue), systemImage: difficulty.icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(difficultyColor)

                // Durata
                Label("\(trail.estimatedMinutes ?? 60) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // N° tappe
                Label("\(trail.steps.count) \(localizer.localizedString(for: "steps_label"))", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}
