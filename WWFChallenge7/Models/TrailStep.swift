//
//  TrailStep.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import Foundation
import SwiftData

// Un singolo step del percorso: da un POI al successivo
@Model
final class TrailStep {
    var id: UUID
    var orderIndex: Int
    var instructions: String     // testo indicazioni (es. "Vai dritto 80m, poi svolta a destra")
    var poi: POI?                // POI di destinazione di questo step

    init(orderIndex: Int, instructions: String, poi: POI? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.instructions = instructions
        self.poi = poi
    }
}