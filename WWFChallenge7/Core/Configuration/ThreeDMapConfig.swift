import Foundation
import SceneKit
import SwiftUI

// MARK: - ThreeDMapType

enum ThreeDMapType: String, CaseIterable, Identifiable {
    case basic    = "Basic 3D"
    case realistic = "Astroni 3D"

    var id: String { rawValue }

    /// Il nome del file USDZ caricato per la mappa
    var modelName: String? {
        switch self {
        case .basic:     return nil
        case .realistic: return "astroni_map_3d"
        }
    }

    var configuration: ThreeDMapMetadata {
        switch self {
        case .basic:
            return ThreeDMapMetadata(
                xScale:   100.0,
                zScale:   100.0,
                xOffset: -50.0,
                zOffset: -50.0,
                markerY:   1.5
            )
        case .realistic:
            return ThreeDMapMetadata(
                xScale:  3344.1,
                zScale:  2675.3,
                xOffset: -1616.6,
                zOffset: -1316.3,
                markerY:  40.0
            )
        }
    }
}

// MARK: - ThreeDMapMetadata

struct ThreeDMapMetadata {
    let xScale: Float
    let zScale: Float
    let xOffset: Float
    let zOffset: Float
    let markerY: Float

    /// Converte le coordinate 2D normalizzate nel perfetto corrispettivo 3D sulla scena
    func worldPosition(for normalizedPoint: CGPoint, in scene: SCNScene?) -> SCNVector3 {
        let x = Float(normalizedPoint.x) * xScale + xOffset
        let z = Float(normalizedPoint.y) * zScale + zOffset
        
        let mapSize = max(xScale, zScale)
        let radius = Float(mapSize) * 0.008
        var finalY = markerY

        // Lancia un raggio dall'alto per trovare l'esatta altezza del terreno in (x, z)
        if let scene = scene {
            let p1 = SCNVector3(x, 10000, z)
            let p2 = SCNVector3(x, -10000, z)
            
            // Fix: In Swift 5+ usiamo .rawValue per trasformare l'opzione in String
            let hits = scene.rootNode.hitTestWithSegment(from: p1, to: p2, options: [
                SCNHitTestOption.boundingBoxOnly.rawValue: NSNumber(value: false),
                SCNHitTestOption.categoryBitMask.rawValue: NSNumber(value: 2),
                SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue
            ])
            
            if let hit = hits.first {
                // Posiziona il marker perfettamente appoggiato al suolo in quel preciso punto
                finalY = hit.worldCoordinates.y + radius
            }
        }
        
        return SCNVector3(x: x, y: finalY, z: z)
    }
}
