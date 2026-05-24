//
//  POIViewModel.swift
//  WWFChallenge7
//
//  MVVM Refactoring for POIModalView
//

import SwiftUI
import Combine

@MainActor
final class POIViewModel: ObservableObject {
    let poi: POI
    
    @Published var isSpeaking = false
    private var cancellables = Set<AnyCancellable>()
    private let voiceService = VoiceService.shared
    
    init(poi: POI) {
        self.poi = poi
        
        // Bind to VoiceService to avoid memory leaks with @StateObject on singletons
        voiceService.$isSpeaking
            .receive(on: RunLoop.main)
            .sink { [weak self] speaking in
                self?.isSpeaking = speaking
            }
            .store(in: &cancellables)
    }
    
    func toggleAudio(text: String, languageCode: String) {
        if voiceService.isSpeaking {
            voiceService.stop()
        } else {
            voiceService.speak(text, languageCode: languageCode)
        }
    }
    
    func stopAudio() {
        if voiceService.isSpeaking {
            voiceService.stop()
        }
    }
    
    // Abstracting network call to decouple from SupabaseConfig in the View layer
    func downloadData(from url: String) async throws -> Data {
        return try await SupabaseConfig.shared.downloadFile(from: url)
    }
}
