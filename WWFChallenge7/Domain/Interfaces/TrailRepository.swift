//
//  TrailRepository.swift
//  WWFChallenge7
//
//  Domain interface — mirrors pattern from GestionaleWWFIpad
//

import Foundation

protocol TrailRepository: Sendable {
    func fetchActiveTrails() async throws -> [Trail]
    func fetchTrailById(_ id: UUID) async throws -> Trail?
    func fetchSteps(forTrailId id: UUID) async throws -> [TrailStep]
}
