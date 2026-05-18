//
//  VoiceService.swift
//  WWFChallenge7
//
//  Provides Text-to-Speech capabilities for offline content.
//

import AVFoundation
import Combine

@MainActor
final class VoiceService: NSObject, ObservableObject {
    
    static let shared = VoiceService()
    
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, languageCode: String? = nil) {
        stop()
        
        let currentLang = languageCode ?? UserDefaults.standard.string(forKey: "preferredLanguage") ?? "it"
        
        let voiceLanguage: String
        switch currentLang {
        case "en": voiceLanguage = "en-US"
        case "de": voiceLanguage = "de-DE"
        case "fr": voiceLanguage = "fr-FR"
        case "it": voiceLanguage = "it-IT"
        default: voiceLanguage = "it-IT"
        }
        
        // Configure AVAudioSession so that it plays even when the physical silent switch is turned ON.
        // It also ducks any other active background audio (like music) while reading.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure AVAudioSession for TTS: \(error.localizedDescription)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            VoiceService.shared.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            VoiceService.shared.isSpeaking = false
        }
    }
}
