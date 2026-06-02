//
//  POIModalView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//  Redesigned — Maggio 2026
//

import SwiftUI
import _SwiftData_SwiftUI
import SceneKit
import AVKit

struct GalleryItem: Identifiable {
    let id: String
    let type: GalleryItemType
    let uiImage: UIImage?
    let remoteURLStr: String?
    let localURL: URL?
    let title: String
    
    enum GalleryItemType {
        case image
        case video
    }
}

struct POIModalView: View {
    let poi: POI
    var onContinue: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var accessibilityPrefs: AccessibilityPreferences
    @StateObject private var viewModel: POIViewModel
    @ObservedObject private var localizer = LocalizationManager.shared

    @Query private var contents: [Content]
    
    // Gallery States
    @State private var selectedGalleryItemId: String? = nil
    @State private var showFullScreenGallery = false
    @State private var showARViewer = false

    init(poi: POI, onContinue: (() -> Void)? = nil) {
        self.poi = poi
        self._viewModel = StateObject(wrappedValue: POIViewModel(poi: poi))
        self.onContinue = onContinue
        let poiId = poi.id
        let filter = #Predicate<Content> { $0.poiId == poiId }
        _contents = Query(filter: filter, sort: \.sortOrder)
    }

    var accentColor: Color {
        poi.type.color
    }

    private var descriptionText: String {
        poi.adaptiveDescription(
            kidsMode: accessibilityPrefs.kidsMode,
            easyReadMode: accessibilityPrefs.easyReadMode
        )
    }

    private var hasARModel: Bool {
        guard let arModelURL = poi.arModelURL else { return false }
        return !arModelURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var galleryItems: [GalleryItem] {
        var items: [GalleryItem] = []
        
        // 1. Cover Photo
        let coverImg: UIImage?
        if let data = poi.photoData {
            coverImg = UIImage(data: data)
        } else {
            coverImg = nil
        }
        
        items.append(
            GalleryItem(
                id: "cover",
                type: .image,
                uiImage: coverImg,
                remoteURLStr: poi.photoURL,
                localURL: nil,
                title: localizer.localizedString(for: "main_photo")
            )
        )
        
        // 2. Extra images and videos
        for content in contents {
            if content.contentType == .image || content.contentType == .video {
                let uiImg: UIImage?
                if let localURL = content.localFileURL,
                   let data = try? Data(contentsOf: localURL) {
                    uiImg = UIImage(data: data)
                } else {
                    uiImg = nil
                }
                
                items.append(
                    GalleryItem(
                        id: content.id.uuidString,
                        type: content.contentType == .image ? .image : .video,
                        uiImage: uiImg,
                        remoteURLStr: content.fileURL,
                        localURL: content.localFileURL,
                        title: localizer.localizedString(for: "content_type_" + content.contentType.rawValue)
                    )
                )
            }
        }
        
        return items
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WWFDesign.Colors.backgroundCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    organicHeader

                    coverPhotoButton

                    POIOrganicCard(shadowColor: accentColor.opacity(0.34)) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(localizer.localizedString(for: "description"))
                                    .font(WWFDesign.Typography.sectionTitle)
                                    .foregroundColor(.black)

                                Spacer(minLength: 8)

                                audioButton
                            }

                            Text(descriptionText)
                                .font(accessibilityPrefs.easyReadMode ? WWFDesign.Typography.bodyLargeRounded : WWFDesign.Typography.trailDescBody)
                                .foregroundColor(.black.opacity(0.82))
                                .lineSpacing(accessibilityPrefs.easyReadMode ? 7 : 5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal)

                    POIMediaGallery(contents: contents) { itemId in
                        selectedGalleryItemId = itemId
                        showFullScreenGallery = true
                    }
                    .padding(.horizontal)

                    if hasARModel {
                        Button {
                            showARViewer = true
                        } label: {
                            Label(localizer.localizedString(for: "open_ar"), systemImage: "camera.viewfinder")
                                .font(WWFDesign.Typography.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(POIOrganicButtonStyle(fill: accentColor, shadow: WWFDesign.Colors.accentAmbra))
                        .padding(.horizontal)
                        .accessibilityLabel(localizer.localizedString(for: "open_ar_accessibility_label"))
                        .accessibilityHint(localizer.localizedString(for: "open_ar_accessibility_hint"))
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "location.fill.viewfinder")
                            .font(WWFDesign.Typography.subheadline)
                        Text(localizer.localizedString(for: "position_updated_on_map"))
                            .font(WWFDesign.Typography.chipLabel)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(WWFDesign.Colors.easyText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(WWFDesign.Colors.easyFill)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.28), lineWidth: 1))
                    .padding(.horizontal)

                    Button {
                        onContinue?() ?? dismiss()
                    } label: {
                        Label(localizer.localizedString(for: "continue_trail"), systemImage: "arrow.right.circle.fill")
                            .font(WWFDesign.Typography.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(POIOrganicButtonStyle(fill: WWFDesign.Colors.forestMid, shadow: accentColor))
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                    .accessibilityLabel(localizer.localizedString(for: "continue_trail"))
                    .accessibilityHint(localizer.localizedString(for: "continue_trail_accessibility_hint"))
                }
                .padding(.top, 16)
            }

            Button {
                onContinue?() ?? dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 42, height: 42)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(WWFDesign.Colors.organicOutline.opacity(0.30), lineWidth: 1.1))
                    .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.trailing, 18)
            .accessibilityLabel(localizer.localizedString(for: "close"))
            .accessibilityHint(localizer.localizedString(for: "close_modal_accessibility_hint"))
        }
        .environmentObject(viewModel)
        .fullScreenCover(isPresented: $showFullScreenGallery) {
            FullScreenGalleryView(items: galleryItems, selectedItemId: $selectedGalleryItemId)
                .environmentObject(viewModel)
        }
        .fullScreenCover(isPresented: $showARViewer) {
            POIARView(poi: poi)
        }
        .onDisappear {
            // Removed voiceService.stop() to allow audio to play in background
        }
    }

    private var organicHeader: some View {
        ZStack(alignment: .bottomLeading) {
            POIHeaderBlobShape()
                .fill(accentColor)
                .overlay(POIHeaderBlobShape().stroke(WWFDesign.Colors.organicOutline.opacity(0.32), lineWidth: 1.3))
                .shadow(color: WWFDesign.Colors.forestDark.opacity(0.10), radius: 9, x: 0, y: 4)

            CardBlobShape()
                .fill(Color.white.opacity(0.18))
                .frame(width: 160)
                .offset(x: -10)
                .accessibilityHidden(true)

            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                    Circle()
                        .stroke(WWFDesign.Colors.organicOutline.opacity(0.30), lineWidth: 1.2)
                    Image(systemName: poi.type.icon)
                        .font(.title2.weight(.bold))
                        .foregroundColor(WWFDesign.Colors.forestDark)
                }
                .frame(width: 58, height: 58)
                .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 8) {
                    Text(poi.localizedName)
                        .font(Font.custom("Georgia", size: 22, relativeTo: .title2).weight(.bold))
                        .foregroundColor(.black)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.82)

                    Text(localizer.localizedString(for: "poi_type_" + poi.type.rawValue))
                        .font(WWFDesign.Typography.badge)
                        .fontWeight(.bold)
                        .foregroundColor(WWFDesign.Colors.forestDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.88))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
                }
            }
            .padding(.leading, 22)
            .padding(.trailing, 72)
            .padding(.bottom, 24)
        }
        .frame(height: 154)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(poi.localizedName). \(localizer.localizedString(for: "poi_type_" + poi.type.rawValue))")
    }

    @ViewBuilder
    private var coverPhotoButton: some View {
        Button {
            selectedGalleryItemId = "cover"
            showFullScreenGallery = true
        } label: {
            ZStack {
                if let data = poi.photoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else if let urlStr = poi.photoURL {
                    RemoteImageView(urlStr: urlStr)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(WWFDesign.Colors.forestMid.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .background(WWFDesign.Colors.easyFill)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.08), radius: 9, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel(localizer.localizedString(for: "main_photo"))
        .accessibilityHint(localizer.localizedString(for: "open_gallery_accessibility_hint"))
    }

    private var audioButton: some View {
        Button {
            viewModel.toggleAudio(
                text: descriptionText,
                languageCode: localizer.preferredLanguage
            )
        } label: {
            Image(systemName: viewModel.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(POIOrganicButtonStyle(fill: Color.white, foreground: .black, shadow: accentColor, verticalPadding: 0))
        .accessibilityLabel(viewModel.isSpeaking ? localizer.localizedString(for: "stop_audio_accessibility_label") : localizer.localizedString(for: "start_audio_accessibility_label"))
        .accessibilityHint(localizer.localizedString(for: "audio_reading_accessibility_hint"))
    }
}

private struct POIHeaderBlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.04, y: h * 0.12))
        path.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.03),
                      control1: CGPoint(x: w * 0.24, y: -h * 0.04),
                      control2: CGPoint(x: w * 0.56, y: h * 0.07))
        path.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.34),
                      control1: CGPoint(x: w * 0.94, y: 0),
                      control2: CGPoint(x: w, y: h * 0.13))
        path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.86),
                      control1: CGPoint(x: w * 0.96, y: h * 0.57),
                      control2: CGPoint(x: w * 0.99, y: h * 0.75))
        path.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.96),
                      control1: CGPoint(x: w * 0.72, y: h * 1.02),
                      control2: CGPoint(x: w * 0.54, y: h * 0.88))
        path.addCurve(to: CGPoint(x: w * 0.04, y: h * 0.78),
                      control1: CGPoint(x: w * 0.22, y: h * 1.07),
                      control2: CGPoint(x: -w * 0.02, y: h * 0.96))
        path.addCurve(to: CGPoint(x: w * 0.04, y: h * 0.12),
                      control1: CGPoint(x: w * 0.10, y: h * 0.52),
                      control2: CGPoint(x: -w * 0.05, y: h * 0.30))
        path.closeSubpath()
        return path
    }
}

private struct POIOrganicCard<ContentView: View>: View {
    var shadowColor: Color = WWFDesign.Colors.leafGreen.opacity(0.35)
    @ViewBuilder var content: () -> ContentView

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    Color.white
                    OrganicBlobShape(variant: 0)
                        .fill(shadowColor.opacity(0.18))
                        .frame(width: 110, height: 80)
                        .offset(x: 30, y: -24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(WWFDesign.Colors.organicOutline.opacity(0.20), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WWFDesign.Colors.organicInset.opacity(0.62), lineWidth: 1).padding(4))
            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}

private struct POIOrganicButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white
    var shadow: Color = WWFDesign.Colors.accentAmbra
    var verticalPadding: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPadding)
            .background(fill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1))
            .shadow(color: WWFDesign.Colors.forestDark.opacity(configuration.isPressed ? 0.04 : 0.09), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// Local Media Gallery for extra downloaded content
struct POIMediaGallery: View {
    let contents: [Content]
    let onSelectImageOrVideo: (String) -> Void
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        if !contents.isEmpty {
            POIOrganicCard(shadowColor: WWFDesign.Colors.accentAmbra.opacity(0.35)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localizer.localizedString(for: "extra_content"))
                        .font(WWFDesign.Typography.sectionTitle)
                        .foregroundColor(.black)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(contents) { content in
                                ContentThumbnailView(content: content, onSelectImageOrVideo: onSelectImageOrVideo)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ContentThumbnailView: View {
    let content: Content
    let onSelectImageOrVideo: (String) -> Void
    @State private var showSheet = false
    @ObservedObject private var localizer = LocalizationManager.shared

    private var localizedTypeName: String {
        localizer.localizedString(for: "content_type_" + content.contentType.rawValue)
    }

    var body: some View {
        Button {
            if content.contentType == .image || content.contentType == .video {
                onSelectImageOrVideo(content.id.uuidString)
            } else {
                showSheet = true
            }
        } label: {
            ZStack {
                if content.contentType == .image {
                    if let localURL = content.localFileURL,
                       let data = try? Data(contentsOf: localURL),
                       let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    } else if let urlStr = content.fileURL {
                        RemoteImageView(urlStr: urlStr)
                            .frame(width: 140, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    } else {
                        placeholderView
                    }
                } else {
                    placeholderView
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                    .stroke(WWFDesign.Colors.organicOutline.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: WWFDesign.Colors.forestDark.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(localizedTypeName)
        .accessibilityHint(localizer.localizedString(for: "media_thumbnail_accessibility_hint"))
        .sheet(isPresented: $showSheet) {
            MediaDetailView(content: content)
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: content.contentType.icon)
                .font(.title)
                .foregroundColor(WWFDesign.Colors.forestLight)
            Text(localizedTypeName)
                .font(WWFDesign.Typography.metaLabel)
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.72))
        }
        .frame(width: 140, height: 100)
        .background(WWFDesign.Colors.easyFill)
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
    }
}

// Full immersive gallery player
struct FullScreenGalleryView: View {
    let items: [GalleryItem]
    @Binding var selectedItemId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: Binding(
                get: { selectedItemId ?? "" },
                set: { selectedItemId = $0 }
            )) {
                ForEach(items) { item in
                    ZStack {
                        switch item.type {
                        case .image:
                            ZoomableImageView(uiImage: item.uiImage, remoteURLStr: item.remoteURLStr)
                        case .video:
                            GalleryVideoPlayerView(url: item.localURL, remoteURLStr: item.remoteURLStr)
                        }
                    }
                    .tag(item.id)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            // Top HUD Overlay
            VStack {
                HStack {
                    if let currentIndex = items.firstIndex(where: { $0.id == selectedItemId }) {
                        Text("\(currentIndex + 1) \(LocalizationManager.shared.localizedString(for: "of_word")) \(items.count)")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(LocalizationManager.shared.localizedString(for: "close"))
                    .accessibilityHint(LocalizationManager.shared.localizedString(for: "close_gallery_accessibility_hint"))
                }
                .padding()

                Spacer()

                // Bottom HUD Caption Overlay
                if let currentIndex = items.firstIndex(where: { $0.id == selectedItemId }) {
                    let currentItem = items[currentIndex]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentItem.title)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

// Pinch-to-zoom and Double-Tap Zoom Image View in pure SwiftUI
struct ZoomableImageView: View {
    let uiImage: UIImage?
    let remoteURLStr: String?

    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else if let urlStr = remoteURLStr {
                    RemoteImageView(urlStr: urlStr)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale * gestureScale)
            .gesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        scale = max(1.0, min(scale * value, 5.0))
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                    } else {
                        scale = 2.0
                    }
                }
            }
        }
    }
}

// Auto-play and Auto-pause video player inside gallery
struct GalleryVideoPlayerView: View {
    let url: URL?
    let remoteURLStr: String?

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func setupPlayer() {
        if let localURL = url {
            let p = AVPlayer(url: localURL)
            self.player = p
            p.play()
        } else if let urlStr = remoteURLStr,
                  let remoteURL = SupabaseConfig.shared.publicStorageURL(for: urlStr) {
            let p = AVPlayer(url: remoteURL)
            self.player = p
            p.play()
        }
    }
}

// Full interactive view for other non-gallery content (audio, 3d, text) in sheet
struct MediaDetailView: View {
    let content: Content
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gamificationService: GamificationService

    var body: some View {
        NavigationStack {
            VStack {
                if let localURL = content.localFileURL {
                    switch content.contentType {
                    case .image:
                        EmptyView() // Handled in fullscreen gallery
                    case .video:
                        EmptyView() // Handled in fullscreen gallery
                    case .audio:
                        AudioPlayerView(url: localURL) {
                            gamificationService.audioGuideListened(content: content)
                        }
                            .padding()
                    case .model3d:
                        Model3DView(url: localURL)
                            .padding()
                    case .text, .transcript:
                        if let textStr = content.text(forLanguage: LocalizationManager.shared.preferredLanguage) {
                            ScrollView {
                                Text(textStr)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            errorView
                        }
                    }
                } else {
                    if let remoteURLStr = content.fileURL,
                       let remoteURL = SupabaseConfig.shared.publicStorageURL(for: remoteURLStr) {
                        switch content.contentType {
                        case .image:
                            EmptyView() // Handled in fullscreen gallery
                        case .video:
                            EmptyView() // Handled in fullscreen gallery
                        case .audio:
                            AudioPlayerView(url: remoteURL) {
                                gamificationService.audioGuideListened(content: content)
                            }
                                .padding()
                        case .model3d:
                            Model3DView(url: remoteURL)
                                .padding()
                        case .text, .transcript:
                            if let textStr = content.text(forLanguage: LocalizationManager.shared.preferredLanguage) {
                                ScrollView {
                                    Text(textStr)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                errorView
                            }
                        }
                    } else if (content.contentType == .text || content.contentType == .transcript), let textStr = content.text(forLanguage: LocalizationManager.shared.preferredLanguage) {
                        ScrollView {
                            Text(textStr)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text(LocalizationManager.shared.localizedString(for: "not_available_offline"))
                                .font(.headline)
                            Text(LocalizationManager.shared.localizedString(for: "part_of_undownloaded_package"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(LocalizationManager.shared.localizedString(for: "content_type_" + content.contentType.rawValue))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationManager.shared.localizedString(for: "close")) {
                        dismiss()
                    }
                    .foregroundColor(WWFDesign.Colors.forestMid)
                }
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(LocalizationManager.shared.localizedString(for: "unable_to_load_local_file"))
                .font(.headline)
        }
        .padding()
    }
}

// Offline-compatible Video Player
struct VideoPlayerView: View {
    let url: URL

    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// Offline-compatible Audio Player Card
struct AudioPlayerView: View {
    let url: URL
    var onCompleted: (() -> Void)? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0.0
    @State private var timer: Timer?
    @State private var duration: TimeInterval = 0.0
    @State private var hasReportedCompletion = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(WWFDesign.Colors.forestLight.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "waveform")
                    .font(.system(size: 54))
                    .foregroundColor(WWFDesign.Colors.forestLight)
            }
            .padding(.top)

            VStack(spacing: 8) {
                Text(LocalizationManager.shared.localizedString(for: "offline_audio_player"))
                    .font(.headline)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            VStack(spacing: 6) {
                Slider(value: $progress, in: 0...1) { editing in
                    if !editing {
                        if let player = audioPlayer {
                            player.currentTime = progress * player.duration
                        }
                    }
                }
                .accentColor(WWFDesign.Colors.forestLight)

                HStack {
                    Text(timeString(time: (audioPlayer?.currentTime ?? 0)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(timeString(time: duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Button {
                if let player = audioPlayer {
                    if player.isPlaying {
                        player.pause()
                        isPlaying = false
                        timer?.invalidate()
                    } else {
                        player.play()
                        isPlaying = true
                        startTimer()
                    }
                }
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(WWFDesign.Colors.forestLight)
            }
            .padding(.bottom)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            setupAudio()
        }
        .onDisappear {
            audioPlayer?.stop()
            timer?.invalidate()
        }
    }

    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            self.audioPlayer = player
            self.duration = player.duration
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = audioPlayer, player.duration > 0 else { return }
            progress = player.currentTime / player.duration
            if progress >= 0.8 && !hasReportedCompletion {
                hasReportedCompletion = true
                onCompleted?()
            }
            if !player.isPlaying {
                isPlaying = false
                timer?.invalidate()
            }
        }
    }

    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Offline-compatible 3D Model Viewer using SceneKit
struct Model3DView: View {
    let url: URL

    var body: some View {
        SceneView(
            scene: try? SCNScene(url: url, options: nil),
            options: [.allowsCameraControl, .autoenablesDefaultLighting]
        )
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// Custom Image Viewer bypassing direct singleton usage
struct RemoteImageView: View {
    let urlStr: String
    @EnvironmentObject var viewModel: POIViewModel
    @State private var uiImage: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let uiImg = uiImage {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(WWFDesign.Colors.forestMid.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(WWFDesign.Colors.forestLight.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard !isLoading, uiImage == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await viewModel.downloadData(from: urlStr)
            if let img = UIImage(data: data) {
                uiImage = img
            }
        } catch {
            print("RemoteImageView failed to load: \(error)")
        }
    }
}
