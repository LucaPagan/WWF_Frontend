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
    @StateObject private var voiceService = VoiceService.shared
    @ObservedObject private var localizer = LocalizationManager.shared

    @Query private var contents: [Content]
    
    // Gallery States
    @State private var selectedGalleryItemId: String? = nil
    @State private var showFullScreenGallery = false

    init(poi: POI, onContinue: (() -> Void)? = nil) {
        self.poi = poi
        self.onContinue = onContinue
        let poiId = poi.id
        let filter = #Predicate<Content> { $0.poiId == poiId }
        _contents = Query(filter: filter, sort: \.sortOrder)
    }

    var accentColor: Color {
        poi.type.color
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
                        title: content.contentType.displayName
                    )
                )
            }
        }
        
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Premium Volcanic Header (Themed with POI accent color)
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                            .fill(WWFDesign.Colors.forestDark)
                            .frame(height: 130)

                        // Pattern organico — cerchi sfumati che evocano vegetazione con colore dell'accento
                        GeometryReader { geo in
                            ZStack {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 35)
                                    .offset(x: geo.size.width * 0.65, y: -20)
                                    .opacity(0.5)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))

                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.25))
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        Circle().stroke(accentColor.opacity(0.4), lineWidth: 0.5)
                                    )
                                    .clipShape(Circle())
                                
                                Image(systemName: poi.type.icon)
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 52, height: 52)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(poi.localizedName)
                                    .font(Font.custom("Georgia", size: 20, relativeTo: .title3).weight(.bold))
                                    .foregroundColor(.white)
                                
                                Text(localizer.localizedString(for: "poi_type_" + poi.type.rawValue))
                                    .font(WWFDesign.Typography.badge)
                                    .fontWeight(.bold)
                                    .foregroundColor(accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Photo (Cover)
                    Button {
                        selectedGalleryItemId = "cover"
                        showFullScreenGallery = true
                    } label: {
                        if let data = poi.photoData, let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                                .padding(.horizontal)
                        } else if let urlStr = poi.photoURL {
                            SupabaseImageView(urlStr: urlStr)
                                .padding(.horizontal)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Description & Audio Reader
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(localizer.localizedString(for: "description"))
                                .font(WWFDesign.Typography.sectionTitle)
                                .foregroundColor(WWFDesign.Colors.forestDark)
                            Spacer()
                            Button {
                                if voiceService.isSpeaking {
                                    voiceService.stop()
                                } else {
                                    voiceService.speak(poi.adaptiveDescription(kidsMode: accessibilityPrefs.kidsMode, easyReadMode: accessibilityPrefs.easyReadMode), languageCode: localizer.preferredLanguage)
                                }
                            } label: {
                                Image(systemName: voiceService.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(accentColor)
                            }
                        }
                        
                        Text(poi.adaptiveDescription(kidsMode: accessibilityPrefs.kidsMode, easyReadMode: accessibilityPrefs.easyReadMode))
                            .font(WWFDesign.Typography.trailDesc)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    // Extra Media (Tiered Content)
                    POIMediaGallery(contents: contents) { itemId in
                        selectedGalleryItemId = itemId
                        showFullScreenGallery = true
                    }
                    .padding(.horizontal)

                    // Updated Position Badge
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill.viewfinder")
                            .foregroundColor(WWFDesign.Colors.leafGreen)
                            .font(.subheadline)
                        Text(localizer.localizedString(for: "position_updated_on_map"))
                            .font(WWFDesign.Typography.metaLabel)
                            .foregroundColor(WWFDesign.Colors.leafGreen)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)

                    // Continue CTA
                    Button {
                        onContinue?() ?? dismiss()
                    } label: {
                        Label(localizer.localizedString(for: "continue_trail"), systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(WWFDesign.Colors.forestMid)
                            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
                            .shadow(color: WWFDesign.Colors.forestMid.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(poi.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizer.localizedString(for: "close")) {
                        onContinue?() ?? dismiss()
                    }
                    .foregroundColor(WWFDesign.Colors.forestMid)
                }
            }
            .fullScreenCover(isPresented: $showFullScreenGallery) {
                FullScreenGalleryView(items: galleryItems, selectedItemId: $selectedGalleryItemId)
            }
            .onDisappear {
                // Removed voiceService.stop() to allow audio to play in background
            }
        }
    }
}

// Local Media Gallery for extra downloaded content
struct POIMediaGallery: View {
    let contents: [Content]
    let onSelectImageOrVideo: (String) -> Void

    var body: some View {
        if !contents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizationManager.shared.localizedString(for: "extra_content"))
                    .font(WWFDesign.Typography.sectionTitle)
                    .foregroundColor(WWFDesign.Colors.forestDark)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(contents) { content in
                            ContentThumbnailView(content: content, onSelectImageOrVideo: onSelectImageOrVideo)
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
                        SupabaseImageView(urlStr: urlStr)
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
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSheet) {
            MediaDetailView(content: content)
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: content.contentType.icon)
                .font(.title)
                .foregroundColor(WWFDesign.Colors.forestLight)
            Text(content.contentType.displayName)
                .font(WWFDesign.Typography.metaLabel)
                .foregroundColor(.secondary)
        }
        .frame(width: 140, height: 100)
        .background(WWFDesign.Colors.forestLight.opacity(0.06))
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
                    SupabaseImageView(urlStr: urlStr)
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
        } else if let urlStr = remoteURLStr, let remoteURL = URL(string: urlStr) {
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
                        AudioPlayerView(url: localURL)
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
                    if let remoteURLStr = content.fileURL, let remoteURL = URL(string: remoteURLStr) {
                        switch content.contentType {
                        case .image:
                            EmptyView() // Handled in fullscreen gallery
                        case .video:
                            EmptyView() // Handled in fullscreen gallery
                        case .audio:
                            AudioPlayerView(url: remoteURL)
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
            .navigationTitle(content.contentType.displayName)
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
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0.0
    @State private var timer: Timer?
    @State private var duration: TimeInterval = 0.0

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

// Custom Image Viewer bypassing default URLSession QUIC issues
struct SupabaseImageView: View {
    let urlStr: String
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
            let data = try await SupabaseConfig.shared.downloadFile(from: urlStr)
            if let img = UIImage(data: data) {
                uiImage = img
            }
        } catch {
            print("SupabaseImageView failed to load: \(error)")
        }
    }
}
