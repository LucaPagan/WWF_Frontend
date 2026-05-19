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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Incapsula l'SCNView in una UIView standard per risolvere i bug di UI Reparenting in SwiftUI
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        
        let scnView = SCNView()
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.frame = container.bounds
        
        // Settings della Scena
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true // CRUCIALE: Risolve l'illuminazione base per PBR
        scnView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60

        let scene = buildScene(context: context)
        scnView.scene = scene
        scnView.pointOfView = context.coordinator.cameraNode

        container.addSubview(scnView)
        context.coordinator.scnView = scnView
        
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
        let camDistance = max(cfg.xScale, cfg.zScale) * 0.85

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
            t.position = SCNVector3(centerX, 0, centerZ)
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
        private let userMarkerKey = "__user__"
        private let startMarkerKey = "__start__"

        init(_ parent: Visitor3DMapView) {
            self.parent = parent
        }

        func refreshMarkers(in scene: SCNScene) {
            markerNodes.values.forEach { $0.removeFromParentNode() }
            markerNodes.removeAll()

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
            for step in parent.trail.sortedSteps {
                guard let poi = step.poi else { continue }
                let isCompleted = parent.completedPOIIds.contains(poi.id)
                let isCurrent   = poi.id == parent.currentStepPOIId

                let color: UIColor = isCompleted ? .gray : isCurrent ? .systemYellow : (UIColor(named: "WWFGreen") ?? .systemGreen)
                let icon = isCompleted ? "checkmark" : poi.type.icon
                let pos  = cfg.worldPosition(for: CGPoint(x: poi.x, y: poi.y), in: scene)

                let node = makePOIMarker(color: color, systemIcon: icon, size: markerSize, isAnimated: isCurrent, label: isCurrent ? poi.name : nil)
                node.position = pos
                scene.rootNode.addChildNode(node)
                markerNodes[poi.id.uuidString] = node
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

        // MARK: Helpers Nodi

        private func makePOIMarker(color: UIColor, systemIcon: String, size: CGFloat, isAnimated: Bool, label: String?) -> SCNNode {
            let root = SCNNode()

            let sphere = SCNSphere(radius: size)
            sphere.segmentCount = 24
            let mat = SCNMaterial()
            mat.diffuse.contents  = color
            mat.specular.contents = UIColor.white
            mat.shininess = 60
            sphere.materials = [mat]

            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.castsShadow = true

            if isAnimated {
                let ring = SCNTorus(ringRadius: size * 1.5, pipeRadius: size * 0.15)
                ring.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.5)
                ring.firstMaterial?.isDoubleSided = true
                let ringNode = SCNNode(geometry: ring)
                root.addChildNode(ringNode)

                let up   = SCNAction.moveBy(x: 0, y: size * 0.8, z: 0, duration: 0.65)
                let down = SCNAction.moveBy(x: 0, y: -size * 0.8, z: 0, duration: 0.65)
                up.timingMode = .easeInEaseOut
                down.timingMode = .easeInEaseOut
                sphereNode.runAction(.repeatForever(.sequence([up, down])))
            }

            root.addChildNode(sphereNode)

            if let text = label {
                let textGeo = SCNText(string: text, extrusionDepth: 0)
                textGeo.font = UIFont.systemFont(ofSize: size * 1.5, weight: .bold)
                textGeo.firstMaterial?.diffuse.contents = UIColor.white
                textGeo.firstMaterial?.isDoubleSided = true
                textGeo.flatness = 0.1

                let textNode = SCNNode(geometry: textGeo)
                let (minB, maxB) = textNode.boundingBox
                textNode.position = SCNVector3(x: -(maxB.x - minB.x) / 2, y: Float(size) * 2.5, z: 0)

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

            for (index, step) in sortedSteps.enumerated() {
                let isCompleted = parent.completedPOIIds.contains(step.poi?.id ?? UUID())
                let isNextActive = step.poi?.id == parent.currentStepPOIId
                
                var segmentPoints: [CGPoint] = []
                
                if let geom = step.pathGeometry, !geom.isEmpty {
                    let coords = PolylineCodec.decode(geom)
                    segmentPoints = coords.map { CGPoint(x: $0.latitude, y: $0.longitude) }
                } else {
                    // Fallback to straight line
                    let startPoint: CGPoint
                    if index == 0 {
                        startPoint = CGPoint(x: parent.trail.startX, y: parent.trail.startY)
                    } else {
                        let prevPOI = sortedSteps[index - 1].poi
                        startPoint = CGPoint(x: prevPOI?.x ?? 0, y: prevPOI?.y ?? 0)
                    }
                    let endPoint = CGPoint(x: step.poi?.x ?? 0, y: step.poi?.y ?? 0)
                    segmentPoints = [startPoint, endPoint]
                }
                
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
                    
                    let radius: CGFloat = isNextActive ? CGFloat(mapSize) * 0.0025 : CGFloat(mapSize) * 0.0012
                    let cyl = SCNCylinder(radius: radius, height: CGFloat(length))
                    let mat = SCNMaterial()
                    
                    let green = UIColor(WWFDesign.Colors.forestLight)
                    if isCompleted {
                        mat.diffuse.contents = UIColor.gray.withAlphaComponent(0.35)
                    } else if isNextActive {
                        mat.diffuse.contents = green
                        mat.emission.contents = green.withAlphaComponent(0.3) // Light glow
                    } else {
                        mat.diffuse.contents = green.withAlphaComponent(0.15)
                    }
                    
                    mat.isDoubleSided = true
                    cyl.materials = [mat]
                    
                    let node = SCNNode(geometry: cyl)
                    node.position = SCNVector3((from3D.x + to3D.x) / 2, (from3D.y + to3D.y) / 2, (from3D.z + to3D.z) / 2)
                    node.name = "trailPath"
                    
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
