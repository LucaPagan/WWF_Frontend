//
//  EventRepository.swift
//  WWFChallenge7
//
//  Domain interface — mirrors pattern from GestionaleWWFIpad
//

import Foundation

protocol EventRepository: Sendable {
    func fetchActiveEvents() async throws -> [Event]
    func fetchEventById(_ id: UUID) async throws -> Event?
}
