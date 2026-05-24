//
//  AudioGuidePlayer.swift
//  WWFChallenge7
//
//  Accessible audio guide player with:
//  - Play/Pause/Seek controls with ≥44pt touch targets
//  - Speed control (0.75x, 1x, 1.25x, 1.5x)
//  - VoiceOver value announcements for progress
//  - Background playback via AVAudioSession
//  - Lock screen controls via MPNowPlayingInfoCenter
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

// MARK: - Audio Player View Model

@MainActor
class AudioPlayerViewModel: ObservableObject {
    private var avPlayer: AVAudioPlayer?
    private var timer: Timer?

    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var rate: Float = 1.0

    func load(url: URL) {
        // Setup AVAudioSession for background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioPlayer: Failed to configure session: \(error)")
        }

        do {
            avPlayer = try AVAudioPlayer(contentsOf: url)
            avPlayer?.prepareToPlay()
            duration = avPlayer?.duration ?? 0
        } catch {
            print("AudioPlayer: Failed to load audio: \(error)")
        }

        setupRemoteCommands()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        avPlayer?.enableRate = true
        avPlayer?.rate = rate
        avPlayer?.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }

    func pause() {
        avPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        updateNowPlayingInfo()
    }

    func seek(by seconds: Double) {
        guard let player = avPlayer else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
        progress = duration > 0 ? newTime / duration : 0
        updateNowPlayingInfo()
    }

    func seekTo(progress: Double) {
        guard let player = avPlayer else { return }
        let newTime = progress * duration
        player.currentTime = newTime
        self.currentTime = newTime
        self.progress = progress
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying {
            avPlayer?.rate = newRate
        }
    }

    func stop() {
        pause()
        avPlayer?.stop()
        avPlayer = nil
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.avPlayer else { return }
                self.currentTime = player.currentTime
                self.progress = self.duration > 0 ? player.currentTime / self.duration : 0

                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.timer?.invalidate()
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.play() }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.seek(by: -10) }
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [10]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.seek(by: 10) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = "Audioguida"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Audio Guide Player View

struct AudioGuidePlayer: View {
    let audioURL: URL
    let title: String
    let durationSeconds: Int?
    @StateObject private var player = AudioPlayerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Title and duration
            HStack {
                Label("Audioguida", systemImage: "headphones")
                    .font(.headline)
                Spacer()
                if let dur = durationSeconds {
                    Text(formatDuration(dur))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress slider
            Slider(value: Binding(
                get: { player.progress },
                set: { player.seekTo(progress: $0) }
            ), in: 0...1)
            .accessibilityLabel("Posizione riproduzione")
            .accessibilityValue(formatDuration(Int(player.currentTime)) + " su " + formatDuration(Int(player.duration)))

            // Time labels
            HStack {
                Text(formatDuration(Int(player.currentTime)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDuration(Int(player.duration)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Controls
            HStack(spacing: 32) {
                // Speed control
                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) { speed in
                        Button("\(speed, specifier: "%.2g")x") {
                            player.setRate(Float(speed))
                        }
                    }
                } label: {
                    Text("\(player.rate, specifier: "%.2g")x")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Velocità riproduzione: \(player.rate, specifier: "%.2g")x")
                .accessibilityHint("Apre le opzioni di velocità riproduzione")

                // Back 10s
                Button(action: { player.seek(by: -10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Torna indietro di 10 secondi")

                // Play/Pause
                Button(action: player.togglePlayback) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(player.isPlaying ? "Pausa" : "Riproduci")
                .accessibilityHint(player.isPlaying ? "Mette in pausa l'audioguida" : "Avvia la riproduzione dell'audioguida")

                // Forward 10s
                Button(action: { player.seek(by: 10) }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Vai avanti di 10 secondi")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear { player.load(url: audioURL) }
        .onDisappear { player.stop() }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
