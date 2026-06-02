import SwiftUI
import SceneKit
import CoreFoundation
internal import _LocationEssentials

struct Visitor3DMapView: UIViewRepresentable {

    let trail: Trail
    let completedPOIIds: Set<UUID>
    let currentStepPOIId: UUID?
    let currentNormalizedPosition: CGPoint
    let navigationState: TrailNavigationState
    let mapType: ThreeDMapType
    var onCompletedPOITap: ((POI) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Incapsula l'SCNView in una UIView standard per risolvere i bug di UI Reparenting in SwiftUI
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(WWFDesign.Colors.backgroundCream)
        
        let scnView = SCNView()
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.frame = container.bounds
        
        // Settings della Scena
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true // CRUCIALE: Risolve l'illuminazione base per PBR
        scnView.backgroundColor = UIColor(WWFDesign.Colors.backgroundCream)
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60

        let scene = buildScene(context: context)
        scnView.scene = scene
        scnView.pointOfView = context.coordinator.cameraNode

        container.addSubview(scnView)
        context.coordinator.scnView = scnView

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        guard let scnView = context.coordinator.scnView, let scene = scnView.scene else { return }
        context.coordinator.refreshMarkers(in: scene)
    }

    // MARK: - Costruzione Scena 3D

    private func buildScene(context: Context) -> SCNScene {
        let scene = SCNScene()

        // ── CRUCIALE: HDR Environment Lighting per texture PBR ─────────────────
        // I modelli esportati in USDZ sono neri senza un ambiente.
        scene.lightingEnvironment.contents = UIColor.white
        scene.lightingEnvironment.intensity = 1.0

        // ── Setup Luci ─────────────────────────────────────────────────────────
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 800 // Schiarisce le ombre pesanti
        ambient.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 2000
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.color = UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(x: -.pi / 3, y: -.pi / 4, z: 0) // Sole diagonale
        scene.rootNode.addChildNode(sunNode)

        // ── Modello Mappa ─────────────────────────────────────────────────────
        switch mapType {
        case .realistic:
            loadRealisticTerrain(into: scene)
        case .basic:
            loadBasicPlane(into: scene)
        }

        // ── Setup Camera ──────────────────────────────────────────────────────
        let cfg = mapType.configuration
        let centerX = cfg.xOffset + cfg.xScale * 0.5
        let centerZ = cfg.zOffset + cfg.zScale * 0.5
        let camDistance = max(cfg.xScale, cfg.zScale) * 1.15

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = Double(max(20_000, camDistance * 4.0))
        cameraNode.camera?.zNear = Double(camDistance * 0.001)
        cameraNode.camera?.fieldOfView = 50
        
        cameraNode.position = SCNVector3(
            x: centerX,
            y: camDistance * 0.75,
            z: centerZ + camDistance * 0.5
        )
        
        let lookAtConstraint = SCNLookAtConstraint(target: {
            let t = SCNNode()
            // Shift target slightly along +Z so the map content appears higher
            t.position = SCNVector3(centerX, 0, centerZ + camDistance * 0.15)
            scene.rootNode.addChildNode(t)
            return t
        }())
        lookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAtConstraint]
        scene.rootNode.addChildNode(cameraNode)
        
        context.coordinator.cameraNode = cameraNode

        // Disegna i pin
        context.coordinator.refreshMarkers(in: scene)

        return scene
    }

    // MARK: - Loaders

    private func loadRealisticTerrain(into scene: SCNScene) {
        guard
            let url = Bundle.main.url(forResource: "astroni_map_3d", withExtension: "usdz"),
            let terrainScene = try? SCNScene(url: url, options: nil)
        else {
            loadBasicPlane(into: scene)
            return
        }

        let terrainNode = terrainScene.rootNode.clone()
        terrainNode.name = "terrain"
        terrainNode.categoryBitMask = 2 // Maschera per il Raycast
        
        terrainNode.enumerateChildNodes { node, _ in
            node.categoryBitMask = 2
            if let geometry = node.geometry {
                for material in geometry.materials {
                    material.isDoubleSided = true // Previene i buchi visivi e mesh invisibili
                    material.ambient.contents = UIColor.white
                }
            }
        }
        
        scene.rootNode.addChildNode(terrainNode)
    }

    private func loadBasicPlane(into scene: SCNScene) {
        let cfg = mapType.configuration
        let plane = SCNPlane(width: CGFloat(cfg.xScale), height: CGFloat(cfg.zScale))

        if let mapImage = UIImage(named: "astroni_map") {
            plane.firstMaterial?.diffuse.contents = mapImage
        } else {
            plane.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.45, blue: 0.22, alpha: 1)
        }
        plane.firstMaterial?.isDoubleSided = true

        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.position = SCNVector3(x: cfg.xOffset + cfg.xScale * 0.5, y: 0, z: cfg.zOffset + cfg.zScale * 0.5)
        planeNode.name = "terrain"
        planeNode.categoryBitMask = 2
        scene.rootNode.addChildNode(planeNode)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: Visitor3DMapView
        var cameraNode: SCNNode = SCNNode()
        weak var scnView: SCNView?

        private var markerNodes: [String: SCNNode] = [:]
        private var markerPOIs: [String: POI] = [:]
        private let userMarkerKey = "__user__"
        private let startMarkerKey = "__start__"

        init(_ parent: Visitor3DMapView) {
            self.parent = parent
        }

        func refreshMarkers(in scene: SCNScene) {
            markerNodes.values.forEach { $0.removeFromParentNode() }
            markerNodes.removeAll()
            markerPOIs.removeAll()

            let cfg = parent.mapType.configuration
            let mapSize = max(cfg.xScale, cfg.zScale)
            
            // Dimensione dinamica per non avere marker minuscoli o giganti!
            let markerSize: CGFloat = CGFloat(mapSize) * 0.008

            // ── Partenza
            let startPos = cfg.worldPosition(for: CGPoint(x: parent.trail.startX, y: parent.trail.startY), in: scene)
            let isAtStart: Bool = {
                if case .atStart = parent.navigationState { return true }
                return false
            }()
            let startNode = makePOIMarker(
                color: UIColor(named: "WWFGreen") ?? .systemGreen,
                systemIcon: "flag.fill",
                size: markerSize * 1.2,
                isAnimated: isAtStart,
                label: parent.trail.startPointName
            )
            startNode.position = startPos
            scene.rootNode.addChildNode(startNode)
            markerNodes[startMarkerKey] = startNode

            // ── POI
            for step in visuallyDistinctMarkerSteps() {
                guard let poi = step.poi else { continue }
                let isCompleted = parent.completedPOIIds.contains(poi.id)
                let isCurrent   = poi.id == parent.currentStepPOIId

                let color: UIColor = isCompleted
                    ? .systemGray
                    : isCurrent
                        ? UIColor(WWFDesign.Colors.leafLight)
                        : (UIColor(named: "WWFGreen") ?? .systemGreen)
                let icon = isCompleted ? "checkmark" : poi.type.icon
                let pos  = cfg.worldPosition(for: CGPoint(x: poi.x, y: poi.y), in: scene)

                let node = makePOIMarker(color: color, systemIcon: icon, size: markerSize, isAnimated: isCurrent, label: isCurrent ? poi.name : nil)
                node.name = poi.id.uuidString
                node.position = pos
                scene.rootNode.addChildNode(node)
                markerNodes[poi.id.uuidString] = node
                if isCompleted {
                    markerPOIs[poi.id.uuidString] = poi
                }
            }

            // ── Posizione Utente
            let userPos = cfg.worldPosition(for: parent.currentNormalizedPosition, in: scene)
            let userNode = makeUserIndicator(mapSize: mapSize)
            userNode.position = userPos
            scene.rootNode.addChildNode(userNode)
            markerNodes[userMarkerKey] = userNode

            // ── Tracciato
            drawTrailPath(in: scene, cfg: cfg, mapSize: mapSize)
        }

        private func visuallyDistinctMarkerSteps() -> [TrailStep] {
            let startPoint = CGPoint(x: parent.trail.startX, y: parent.trail.startY)
            var seenPOIIds = Set<UUID>()
            var seenPoints: [CGPoint] = []
            var result: [TrailStep] = []

            for step in parent.trail.sortedSteps {
                guard let poi = step.poi else { continue }

                guard seenPOIIds.insert(poi.id).inserted else { continue }

                let point = CGPoint(x: poi.x, y: poi.y)
                if isSameVisualPoint(point, startPoint) { continue }
                if seenPoints.contains(where: { isSameVisualPoint($0, point) }) { continue }

                seenPoints.append(point)
                result.append(step)
            }

            return result
        }

        private func isSameVisualPoint(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
            let dx = lhs.x - rhs.x
            let dy = lhs.y - rhs.y
            return hypot(dx, dy) < 0.012
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: [.boundingBoxOnly: true])
            for hit in hits {
                var node: SCNNode? = hit.node
                while let current = node {
                    if let name = current.name, let poi = markerPOIs[name] {
                        parent.onCompletedPOITap?(poi)
                        return
                    }
                    node = current.parent
                }
            }
        }

        // MARK: Helpers Nodi

        private func makePOIMarker(color: UIColor, systemIcon: String, size: CGFloat, isAnimated: Bool, label: String?) -> SCNNode {
            let root = SCNNode()

            let shadow = SCNCylinder(radius: size * 0.92, height: size * 0.035)
            shadow.radialSegmentCount = 40
            let shadowMat = SCNMaterial()
            shadowMat.diffuse.contents = UIColor(WWFDesign.Colors.forestDark).withAlphaComponent(0.18)
            shadowMat.transparency = 0.30
            shadow.materials = [shadowMat]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.position = SCNVector3(0, Float(size) * 0.02, 0)
            root.addChildNode(shadowNode)

            let stemHeight = size * 1.30
            let stem = SCNCone(topRadius: size * 0.48, bottomRadius: 0, height: stemHeight)
            stem.radialSegmentCount = 40
            let stemMat = SCNMaterial()
            stemMat.diffuse.contents = color
            stemMat.emission.contents = color.withAlphaComponent(isAnimated ? 0.18 : 0.05)
            stemMat.specular.contents = UIColor.white.withAlphaComponent(0.7)
            stemMat.roughness.contents = NSNumber(value: 0.30)
            stem.materials = [stemMat]
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(0, Float(stemHeight / 2), 0)
            stemNode.castsShadow = true
            root.addChildNode(stemNode)

            let sphere = SCNSphere(radius: size)
            sphere.segmentCount = 48
            let mat = SCNMaterial()
            mat.diffuse.contents  = color
            mat.emission.contents = isAnimated ? color.withAlphaComponent(0.20) : color.withAlphaComponent(0.06)
            mat.specular.contents = UIColor.white
            mat.metalness.contents = NSNumber(value: 0.08)
            mat.roughness.contents = NSNumber(value: 0.34)
            mat.shininess = 48
            sphere.materials = [mat]

            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = SCNVector3(0, Float(stemHeight + size * 0.48), 0)
            sphereNode.castsShadow = true

            if isAnimated {
                let pulse = SCNSphere(radius: size * 1.18)
                pulse.segmentCount = 40
                let pulseMat = SCNMaterial()
                pulseMat.diffuse.contents = color.withAlphaComponent(0.10)
                pulseMat.emission.contents = color.withAlphaComponent(0.22)
                pulseMat.transparency = 0.18
                pulse.materials = [pulseMat]
                let pulseNode = SCNNode(geometry: pulse)
                pulseNode.position = sphereNode.position
                pulseNode.castsShadow = false
                root.addChildNode(pulseNode)
                pulseNode.runAction(.repeatForever(.sequence([
                    .scale(to: 1.14, duration: 0.9),
                    .scale(to: 1.0, duration: 0.9)
                ])))
            }

            root.addChildNode(sphereNode)

            if let text = label {
                let textGeo = SCNText(string: text, extrusionDepth: 0)
                textGeo.font = UIFont.systemFont(ofSize: size * 1.55, weight: .heavy)
                textGeo.alignmentMode = CATextLayerAlignmentMode.center.rawValue
                textGeo.firstMaterial?.diffuse.contents = UIColor.white
                textGeo.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.18)
                textGeo.firstMaterial?.specular.contents = UIColor.white
                textGeo.firstMaterial?.isDoubleSided = true
                textGeo.flatness = 0.03

                let textNode = SCNNode(geometry: textGeo)
                let (minB, maxB) = textNode.boundingBox
                let textWidth = maxB.x - minB.x
                textNode.position = SCNVector3(x: -textWidth / 2, y: Float(stemHeight + size * 2.25), z: 0)

                let billboard = SCNBillboardConstraint()
                billboard.freeAxes = .Y
                textNode.constraints = [billboard]

                root.addChildNode(textNode)
            }

            return root
        }

        private func makeUserIndicator(mapSize: Float) -> SCNNode {
            let root = SCNNode()
            let r = CGFloat(mapSize) * 0.006

            let outerSphere = SCNSphere(radius: r * 1.8)
            outerSphere.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.25)
            outerSphere.firstMaterial?.isDoubleSided = true
            let outerNode = SCNNode(geometry: outerSphere)

            outerNode.runAction(.repeatForever(.sequence([
                .scale(to: 1.4, duration: 0.9), .scale(to: 1.0, duration: 0.9)
            ])))
            root.addChildNode(outerNode)

            let inner = SCNSphere(radius: r)
            inner.segmentCount = 24
            let mat = SCNMaterial()
            mat.diffuse.contents  = UIColor.systemBlue
            mat.specular.contents = UIColor.white
            mat.shininess = 80
            inner.materials = [mat]
            let innerNode = SCNNode(geometry: inner)
            innerNode.castsShadow = true
            root.addChildNode(innerNode)

            return root
        }

        private func drawTrailPath(in scene: SCNScene, cfg: ThreeDMapMetadata, mapSize: Float) {
            scene.rootNode.childNodes.filter { $0.name == "trailPath" }.forEach { $0.removeFromParentNode() }

            let sortedSteps = parent.trail.sortedSteps
            guard !sortedSteps.isEmpty else { return }

            for step in sortedSteps {
                let isCompleted = parent.completedPOIIds.contains(step.poi?.id ?? UUID())
                let isNextActive = step.poi?.id == parent.currentStepPOIId
                
                guard
                    let geom = step.pathGeometry?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !geom.isEmpty
                else { continue }

                let segmentPoints = PolylineCodec.decode(geom).map { CGPoint(x: $0.latitude, y: $0.longitude) }
                
                guard segmentPoints.count >= 2 else { continue }
                
                // Draw each piece of the segment
                for i in 0..<(segmentPoints.count - 1) {
                    let from3D = cfg.worldPosition(for: segmentPoints[i], in: scene)
                    let to3D   = cfg.worldPosition(for: segmentPoints[i+1], in: scene)
                    
                    let dx = to3D.x - from3D.x
                    let dy = to3D.y - from3D.y
                    let dz = to3D.z - from3D.z
                    let length = sqrt(dx*dx + dy*dy + dz*dz)
                    
                    guard length > 1e-4 else { continue }
                    
                    let radius: CGFloat = isNextActive ? CGFloat(mapSize) * 0.00125 : CGFloat(mapSize) * 0.00062
                    let cyl = SCNCylinder(radius: radius, height: CGFloat(length))
                    let mat = SCNMaterial()
                    
                    let green = UIColor(WWFDesign.Colors.forestLight)
                    if isCompleted {
                        mat.diffuse.contents = UIColor(WWFDesign.Colors.cardCream).withAlphaComponent(0.52)
                        mat.emission.contents = UIColor.white.withAlphaComponent(0.08)
                    } else if isNextActive {
                        mat.diffuse.contents = green
                        mat.emission.contents = green.withAlphaComponent(0.38)
                        mat.specular.contents = UIColor.white
                        mat.metalness.contents = NSNumber(value: 0.12)
                        mat.roughness.contents = NSNumber(value: 0.24)
                    } else {
                        mat.diffuse.contents = green.withAlphaComponent(0.46)
                        mat.emission.contents = green.withAlphaComponent(0.12)
                    }
                    
                    mat.isDoubleSided = true
                    cyl.materials = [mat]
                    
                    let node = SCNNode(geometry: cyl)
                    node.position = SCNVector3((from3D.x + to3D.x) / 2, (from3D.y + to3D.y) / 2, (from3D.z + to3D.z) / 2)
                    node.name = "trailPath"

                    if isNextActive {
                        let glow = SCNCylinder(radius: radius * 1.9, height: CGFloat(length))
                        let glowMat = SCNMaterial()
                        glowMat.diffuse.contents = green.withAlphaComponent(0.08)
                        glowMat.emission.contents = green.withAlphaComponent(0.18)
                        glowMat.transparency = 0.18
                        glowMat.isDoubleSided = true
                        glow.materials = [glowMat]
                        let glowNode = SCNNode(geometry: glow)
                        node.addChildNode(glowNode)
                    }
                    
                    let dir = SCNVector3(dx / length, dy / length, dz / length)
                    let dot = upVector.x*dir.x + upVector.y*dir.y + upVector.z*dir.z
                    let cross = SCNVector3(upVector.y*dir.z - upVector.z*dir.y, upVector.z*dir.x - upVector.x*dir.z, upVector.x*dir.y - upVector.y*dir.x)
                    let crossLen = sqrt(cross.x*cross.x + cross.y*cross.y + cross.z*cross.z)
                    
                    node.rotation = crossLen < 1e-6 ? (dot > 0 ? SCNVector4(0, 1, 0, 0) : SCNVector4(1, 0, 0, CoreFoundation.CGFloat.pi)) : SCNVector4(cross.x / crossLen, cross.y / crossLen, cross.z / crossLen, atan2(crossLen, dot))
                    
                    scene.rootNode.addChildNode(node)
                }
            }
        }
        
        private let upVector = SCNVector3(0, 1, 0)
    }
}
