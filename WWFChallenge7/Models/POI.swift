import Foundation
import SwiftData
import CoreGraphics

@Model
final class POI {
    var id: UUID
    var name: String
    var poiDescription: String
    var x: Double // posizione normalizzata sulla mappa (0.0 - 1.0)
    var y: Double
    var type: POIType
    var photoData: Data?
    var qrPayload: String // stringa univoca encodata nel QR fisico

    init(
        name: String,
        description: String,
        x: Double,
        y: Double,
        type: POIType = .generic,
        photoData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.poiDescription = description
        self.x = x
        self.y = y
        self.type = type
        self.photoData = photoData
        self.qrPayload = "ASTRONI_POI_\(self.id.uuidString)"
    }
}

enum POIType: String, Codable, CaseIterable {
    case generic     = "Generico"
    case nature      = "Natura"
    case historical  = "Storico"
    case service     = "Servizio"
    case viewpoint   = "Belvedere"
    case danger      = "Attenzione"

    var icon: String {
        switch self {
        case .generic:    return "mappin.circle.fill"
        case .nature:     return "leaf.fill"
        case .historical: return "building.columns.fill"
        case .service:    return "wrench.and.screwdriver.fill"
        case .viewpoint:  return "binoculars.fill"
        case .danger:     return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .generic:    return "#5C8A5C"
        case .nature:     return "#2E7D32"
        case .historical: return "#795548"
        case .service:    return "#1565C0"
        case .viewpoint:  return "#6A1B9A"
        case .danger:     return "#C62828"
        }
    }
}