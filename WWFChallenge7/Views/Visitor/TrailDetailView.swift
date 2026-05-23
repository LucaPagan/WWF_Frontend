//
//  TrailDetailView.swift
//  WWFChallenge7
//
//  Redesigned — Maggio 2026
//

import SwiftUI
import SwiftData

struct TrailDetailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss
    @State private var startTrail = false
    @State private var showDownloadOptions = false
    @State private var isManagingPackages = false
    @EnvironmentObject var downloadManager: DownloadManager
    @ObservedObject private var localizer = LocalizationManager.shared
    @EnvironmentObject var accessibilityPrefs: AccessibilityPreferences

    private var difficulty: TrailDifficulty {
        trail.difficulty ?? .easy
    }

    private var badgeFill: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.easyFill
        case .medium: return WWFDesign.Colors.mediumFill
        case .hard:   return WWFDesign.Colors.hardFill
        }
    }

    private var badgeText: Color {
        switch difficulty {
        case .easy:   return WWFDesign.Colors.easyText
        case .medium: return WWFDesign.Colors.mediumText
        case .hard:   return WWFDesign.Colors.hardText
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Premium Hero Header (Bleeds into notch / status bar)
                    ZStack(alignment: .topLeading) {
                        // Sfondo scuro bosco
                        WWFDesign.Colors.forestDark
                            .frame(height: 260)
                        
                        // Pattern organico — cerchi sfumati che evocano vegetazione
                        GeometryReader { geo in
                            ZStack {
                                Circle()
                                    .fill(WWFDesign.Colors.forestMid)
                                    .frame(width: 250, height: 250)
                                    .blur(radius: 60)
                                    .offset(x: geo.size.width * 0.5, y: -40)
                                    .opacity(0.65)

                                Circle()
                                    .fill(WWFDesign.Colors.forestLight)
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 40)
                                    .offset(x: geo.size.width * 0.7, y: 80)
                                    .opacity(0.3)
                            }
                        }
                        
                        // Foglia decorativa in alto a destra
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 140))
                            .foregroundColor(WWFDesign.Colors.leafGreen.opacity(0.06))
                            .rotationEffect(.degrees(-25))
                            .offset(x: UIScreen.main.bounds.width - 150, y: 30)
                            .accessibilityHidden(true)
                        
                        // Contenuto testuale (solo titolo) allineato in basso
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            
                            // Titolo Percorso
                            Text(trail.localizedName)
                                .font(Font.custom("Georgia", size: 30, relativeTo: .largeTitle).weight(.bold))
                                .foregroundColor(Color(red: 0.941, green: 0.929, blue: 0.902))
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                        .frame(height: 260, alignment: .leading)
                        
                        // Top Row: Pulsante indietro e Badge difficoltà sulla stessa riga
                        HStack(alignment: .center) {
                            // Pulsante indietro floating botanico (vetro sfumato nei toni della riserva)
                            Button {
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(WWFDesign.Colors.forestMid.opacity(0.35))
                                        .background(.ultraThinMaterial)
                                        .overlay(
                                            Circle().stroke(WWFDesign.Colors.leafGreen.opacity(0.35), lineWidth: 0.5)
                                        )
                                        .clipShape(Circle())
                                    
                                    Image(systemName: "chevron.left")
                                        .font(.headline)
                                        .foregroundColor(WWFDesign.Colors.leafLight)
                                        .offset(x: -1)
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                            }
                            .accessibilityLabel("Torna indietro")
                            
                            Spacer()
                            
                            // Badge difficoltà allineato a destra sulla stessa riga
                            Text(localizer.localizedString(for: "difficulty_" + difficulty.rawValue))
                                .font(WWFDesign.Typography.badge)
                                .fontWeight(.semibold)
                                .tracking(0.3)
                                .foregroundColor(badgeText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(badgeFill)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 54) // Posizionato sotto la Dynamic Island / Notch
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 260)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: WWFDesign.Radius.hero,
                            bottomTrailingRadius: WWFDesign.Radius.hero,
                            topTrailingRadius: 0
                        )
                    )
                    
                    // Quick Stats Strip
                    HStack(spacing: 16) {
                        // Durata
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(WWFDesign.Colors.forestLight)
                            Text("\(trail.estimatedMinutes ?? 60) min")
                                .font(WWFDesign.Typography.chipLabel)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .overlay(
                            Capsule().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                        )
                        .clipShape(Capsule())

                        // Tappe
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundColor(WWFDesign.Colors.forestLight)
                            Text("\(trail.steps.count) \(localizer.localizedString(for: "steps_label"))")
                                .font(WWFDesign.Typography.chipLabel)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .overlay(
                            Capsule().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // Descrizione Percorso Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizer.localizedString(for: "description"))
                            .font(WWFDesign.Typography.sectionTitle)
                            .foregroundColor(WWFDesign.Colors.forestDark)
                        
                        Text(trail.adaptiveDescription(kidsMode: accessibilityPrefs.kidsMode, easyReadMode: accessibilityPrefs.easyReadMode))
                            .font(WWFDesign.Typography.trailDesc)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Warning / Offline mode info
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.headline)
                            .foregroundColor(WWFDesign.Colors.warningText)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizer.localizedString(for: "offline_mode"))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(WWFDesign.Colors.warningText)

                            Text(localizer.localizedString(for: "offline_navigation_desc"))
                                .font(WWFDesign.Typography.trailDesc)
                                .foregroundColor(WWFDesign.Colors.warningBody)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WWFDesign.Colors.warningFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: WWFDesign.Radius.warning)
                            .stroke(WWFDesign.Colors.warningBorder, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.warning))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Trail Steps Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(localizer.localizedString(for: "trail_steps"))
                            .font(WWFDesign.Typography.sectionTitle)
                            .foregroundColor(WWFDesign.Colors.forestDark)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 0) {
                            let steps = trail.sortedSteps
                            ForEach(steps.indices, id: \.self) { index in
                                TrailStepRowView(
                                    step: steps[index],
                                    index: index,
                                    isLast: index == steps.count - 1
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            // CTA Floating bar at the bottom
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    
                    let packages = downloadManager.packages(forTrailId: trail.id)
                    let isDownloaded = packages.contains(where: { $0.isDownloaded })
                    
                    VStack(spacing: 12) {
                        if isDownloaded {
                            Button {
                                isManagingPackages = false
                                startTrail = true
                            } label: {
                                Label(localizer.localizedString(for: "continue_offline"), systemImage: "play.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(WWFDesign.Colors.forestLight)
                                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                                    .shadow(color: WWFDesign.Colors.forestLight.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            Button {
                                isManagingPackages = true
                                showDownloadOptions = true
                            } label: {
                                Label(localizer.localizedString(for: "manage_packages"), systemImage: "arrow.down.circle.fill")
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(WWFDesign.Colors.forestDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                                            .stroke(WWFDesign.Colors.forestDark.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            }
                        } else {
                            Button {
                                isManagingPackages = false
                                showDownloadOptions = true
                            } label: {
                                Label(localizer.localizedString(for: "download_and_start"), systemImage: "icloud.and.arrow.down.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(WWFDesign.Colors.forestDark)
                                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                                    .shadow(color: WWFDesign.Colors.forestDark.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
            .fullScreenCover(isPresented: $startTrail) {
                ActiveTrailView(trail: trail)
            }
            .sheet(isPresented: $showDownloadOptions) {
                DownloadSelectionView(trail: trail) {
                    showDownloadOptions = false
                    if !isManagingPackages {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            startTrail = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Premium Step Row

struct TrailStepRowView: View {
    let step: TrailStep
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator with botanical colors
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(WWFDesign.Colors.forestLight)
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(WWFDesign.Colors.forestLight.opacity(0.25))
                        .frame(width: 2, height: 42)
                }
            }

            // Step Content Card
            VStack(alignment: .leading, spacing: 6) {
                if let poi = step.poi {
                    Text(poi.localizedName)
                        .font(WWFDesign.Typography.trailName)
                        .foregroundColor(.primary)
                }
                
                Text(step.instructions)
                    .font(WWFDesign.Typography.trailDesc)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, isLast ? 0 : 20)
            }
            .padding(.top, 3)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index + 1): \(step.poi?.localizedName ?? ""). \(step.instructions). \(step.distanceMeters) metri, circa \(step.estimatedMinutes) minuti.")
    }
}

// MARK: - Previews

struct TrailDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            Trail.self,
            POI.self,
            TrailStep.self,
            Event.self,
            Content.self,
            DownloadPackage.self,
            UserProfile.self,
            LocalTranslation.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = container.mainContext
        
        let trail = Trail(name: "Sentiero del Lago Grande", description: "Passeggiata panoramica attorno al lago vulcanico principale")
        trail.difficulty = .easy
        trail.estimatedMinutes = 60
        trail.isActive = true
        
        let poi = POI(name: "Lago Grande", description: "Punto panoramico sul lago vulcanico principale", x: 0.1, y: 0.1)
        let step = TrailStep(stepOrder: 1)
        step.instructions = "Cammina lungo la passerella di legno per raggiungere il canneto."
        
        context.insert(trail)
        context.insert(poi)
        context.insert(step)
        
        step.poi = poi
        trail.steps = [step]
        
        return TrailDetailView(trail: trail)
            .modelContainer(container)
            .environmentObject(DownloadManager())
            .previewDisplayName("Dettaglio Percorso — Facile")
    }
}
