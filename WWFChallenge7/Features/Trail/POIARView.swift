//
//  POIARView.swift
//  WWFChallenge7
//

import ARKit
import QuartzCore
import SceneKit
import SwiftUI

struct POIARView: View {
    let poi: POI

    @Environment(\.dismiss) private var dismiss
    @State private var localModelURL: URL?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let localModelURL {
                ARSceneContainer(
                    modelURL: localModelURL,
                    poiName: poi.name,
                    animationConfig: ARAnimationConfig.decode(from: poi.arAnimationConfig)
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(poi.localizedName)
                            .font(.headline)
                        Text(isLoading ? "Preparazione modello AR..." : "Tocca un piano per posizionare il modello")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .task {
            await prepareModel()
        }
        .alert("AR non disponibile", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Chiudi", role: .cancel) { dismiss() }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func prepareModel() async {
        guard ARWorldTrackingConfiguration.isSupported else {
            errorMessage = "ARKit non è supportato su questo dispositivo."
            isLoading = false
            return
        }

        guard let remoteURL = poi.arModelURL, !remoteURL.isEmpty else {
            errorMessage = "Questo POI non ha un modello AR associato."
            isLoading = false
            return
        }

        do {
            localModelURL = try await ARModelCache.shared.localURL(for: remoteURL)
        } catch {
            errorMessage = "Download modello AR non riuscito: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct ARSceneContainer: UIViewRepresentable {
    let modelURL: URL
    let poiName: String
    let animationConfig: ARAnimationConfig

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true
        view.scene = SCNScene()

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        let rotation = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        view.addGestureRecognizer(rotation)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        tap.delegate = context.coordinator
        pinch.delegate = context.coordinator
        rotation.delegate = context.coordinator
        pan.delegate = context.coordinator
        context.coordinator.sceneView = view

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(modelURL: modelURL, poiName: poiName, animationConfig: animationConfig)
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, UIGestureRecognizerDelegate {
        weak var sceneView: ARSCNView?
        private let modelURL: URL
        private let poiName: String
        private let animationConfig: ARAnimationConfig
        private var placedNode: SCNNode?
        private var placedBaseScale = SCNVector3(1, 1, 1)
        private var userScaleFactor: Float = 1
        private var currentRotationY: Float = 0

        init(modelURL: URL, poiName: String, animationConfig: ARAnimationConfig) {
            self.modelURL = modelURL
            self.poiName = poiName
            self.animationConfig = animationConfig
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let sceneView else { return }
            let location = recognizer.location(in: sceneView)
            guard let placementPosition = placementPosition(at: location, in: sceneView, allowCameraFallback: true) else { return }

            placedNode?.removeFromParentNode()

            do {
                let source = SCNSceneSource(url: modelURL, options: nil)
                let scene = try source?.scene(options: nil) ?? SCNScene(url: modelURL, options: nil)
                let container = SCNNode()
                for child in scene.rootNode.childNodes {
                    container.addChildNode(child.clone())
                }
                container.position = placementPosition
                playEmbeddedAnimations(in: container, from: source)
                if isCraterExperience {
                    let craterParts = prepareCraterAsset(container)
                    normalize(container, targetFootprintMeters: 2.65)
                    anchor(container, at: placementPosition, verticalSink: 0.22)
                    faceCamera(container, in: sceneView)
                    playCraterReveal(on: container, craterParts: craterParts)
                } else {
                    normalize(container, targetFootprintMeters: 0.7)
                    anchor(container, at: placementPosition, verticalSink: 0)
                    applyAnimations(to: container)
                }
                sceneView.scene.rootNode.addChildNode(container)
                placedNode = container
                placedBaseScale = container.scale
                userScaleFactor = 1
                currentRotationY = container.eulerAngles.y
            } catch {
                assertionFailure("Unable to load AR model: \(error.localizedDescription)")
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let sceneView, let placedNode else { return }
            let location = recognizer.location(in: sceneView)
            guard let placementPosition = placementPosition(at: location, in: sceneView, allowCameraFallback: false) else { return }

            let sink: Float = isCraterExperience ? 0.22 : 0
            placedNode.position = SCNVector3(
                placementPosition.x,
                placementPosition.y - sink,
                placementPosition.z
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let placedNode else { return }
            if recognizer.state == .changed || recognizer.state == .ended {
                let proposed = userScaleFactor * Float(recognizer.scale)
                let clamped = min(max(proposed, 0.55), 2.4)
                placedNode.scale = SCNVector3(
                    placedBaseScale.x * clamped,
                    placedBaseScale.y * clamped,
                    placedBaseScale.z * clamped
                )
                if recognizer.state == .ended {
                    userScaleFactor = clamped
                    recognizer.scale = 1
                }
            }
        }

        @objc func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
            guard let placedNode else { return }
            if recognizer.state == .changed || recognizer.state == .ended {
                placedNode.eulerAngles.y = currentRotationY - Float(recognizer.rotation)
                if recognizer.state == .ended {
                    currentRotationY = placedNode.eulerAngles.y
                    recognizer.rotation = 0
                }
            }
        }

        private var isCraterExperience: Bool {
            let loweredName = poiName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let loweredFile = modelURL.lastPathComponent.lowercased()
            return loweredName.contains("cratere") || loweredFile.contains("lava") || loweredFile.contains("crater")
        }

        private func normalize(_ node: SCNNode, targetFootprintMeters: Float) {
            let (minBounds, maxBounds) = node.boundingBox
            let width = maxBounds.x - minBounds.x
            let height = maxBounds.y - minBounds.y
            let depth = maxBounds.z - minBounds.z
            let footprint = max(width, depth)
            let referenceDimension = footprint > 0 ? footprint : max(width, max(height, depth))
            if referenceDimension > 0 {
                let scale = targetFootprintMeters / referenceDimension
                node.scale = SCNVector3(scale, scale, scale)
            }
            node.pivot = SCNMatrix4MakeTranslation(
                (minBounds.x + maxBounds.x) / 2,
                minBounds.y,
                (minBounds.z + maxBounds.z) / 2
            )
        }

        private func anchor(_ node: SCNNode, at position: SCNVector3, verticalSink: Float) {
            node.position = SCNVector3(
                position.x,
                position.y - verticalSink,
                position.z
            )
        }

        private func placementPosition(at location: CGPoint, in sceneView: ARSCNView, allowCameraFallback: Bool) -> SCNVector3? {
            if let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal),
               let result = sceneView.session.raycast(query).first {
                return SCNVector3(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
            }

            let hitResults = sceneView.hitTest(location, types: [
                .existingPlaneUsingExtent,
                .existingPlane,
                .estimatedHorizontalPlane
            ])
            if let result = hitResults.first {
                return SCNVector3(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
            }

            guard allowCameraFallback, let pointOfView = sceneView.pointOfView else { return nil }
            let transform = pointOfView.simdWorldTransform
            let cameraPosition = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let forward = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
            let target = cameraPosition + forward * 1.45
            return SCNVector3(target.x, target.y - 1.05, target.z)
        }

        private func faceCamera(_ node: SCNNode, in sceneView: ARSCNView) {
            guard let cameraNode = sceneView.pointOfView else { return }
            let cameraPosition = cameraNode.worldPosition
            let dx = cameraPosition.x - node.position.x
            let dz = cameraPosition.z - node.position.z
            guard abs(dx) > 0.001 || abs(dz) > 0.001 else { return }
            node.eulerAngles.y = atan2(dx, dz) + .pi / 2
        }

        private func applyAnimations(to node: SCNNode) {
            let speed = max(animationConfig.speed, 0.1)

            if animationConfig.rotationEnabled {
                let rotation = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 6.0 / speed)
                node.runAction(.repeatForever(rotation), forKey: "wwf.ar.rotation")
            }

            if animationConfig.floatingEnabled {
                let up = SCNAction.moveBy(x: 0, y: animationConfig.floatAmplitude, z: 0, duration: 1.4 / speed)
                up.timingMode = .easeInEaseOut
                let down = up.reversed()
                node.runAction(.repeatForever(.sequence([up, down])), forKey: "wwf.ar.float")
            }

            if animationConfig.pulseEnabled {
                let pulseScale = Float(max(animationConfig.pulseScale, 1.0))
                let grow = SCNAction.scale(by: CGFloat(pulseScale), duration: 0.9 / speed)
                grow.timingMode = .easeInEaseOut
                let shrink = grow.reversed()
                shrink.timingMode = .easeInEaseOut
                node.runAction(.repeatForever(.sequence([grow, shrink])), forKey: "wwf.ar.pulse")
            }
        }

        private func playEmbeddedAnimations(in node: SCNNode, from source: SCNSceneSource?) {
            node.enumerateHierarchy { child, _ in
                for key in child.animationKeys {
                    child.animationPlayer(forKey: key)?.play()
                }
            }

            guard let source else { return }
            let animationIds = source.identifiersOfEntries(withClass: CAAnimation.self)
            for id in animationIds {
                guard let animation = source.entryWithIdentifier(id, withClass: CAAnimation.self) else { continue }
                animation.repeatCount = .greatestFiniteMagnitude
                animation.autoreverses = false
                node.addAnimation(animation, forKey: "wwf.embedded.\(id)")
            }
        }

        private struct CraterParts {
            var opening: [SCNNode]
            var lava: [SCNNode]
        }

        private func prepareCraterAsset(_ node: SCNNode) -> CraterParts {
            let rootBounds = node.boundingBox
            let rootWidth = rootBounds.max.x - rootBounds.min.x
            let rootHeight = max(rootBounds.max.y - rootBounds.min.y, 0.001)
            let rootDepth = rootBounds.max.z - rootBounds.min.z
            let rootCenter = SCNVector3(
                (rootBounds.min.x + rootBounds.max.x) / 2,
                (rootBounds.min.y + rootBounds.max.y) / 2,
                (rootBounds.min.z + rootBounds.max.z) / 2
            )
            var openingParts: [SCNNode] = []
            var lavaParts: [SCNNode] = []

            node.enumerateHierarchy { child, _ in
                guard let geometry = child.geometry else { return }
                geometry.materials = geometry.materials.map { material in
                    (material.copy() as? SCNMaterial) ?? material
                }
                let role = craterRole(
                    for: child,
                    root: node,
                    rootBounds: rootBounds,
                    rootCenter: rootCenter,
                    rootFootprint: max(rootWidth, rootDepth),
                    rootHeight: rootHeight
                )

                let isLavaPart = role == .lava

                for material in geometry.materials {
                    material.isDoubleSided = true
                    if isLavaPart {
                        applyLavaMaterial(material)
                    } else {
                        applyBasaltMaterial(material)
                    }
                }

                if role == .openingCap {
                    openingParts.append(child)
                } else if isLavaPart {
                    lavaParts.append(child)
                }
            }

            if openingParts.isEmpty {
                let fallbackParts = geometryNodes(in: node).filter { child in
                    let center = centerOfNode(child, relativeTo: node)
                    return center.y > rootBounds.min.y + rootHeight * 0.45
                }
                openingParts = fallbackParts.count > 1 ? fallbackParts : []
            }

            if lavaParts.isEmpty {
                let fallbackLava = geometryNodes(in: node).filter { child in
                    let center = centerOfNode(child, relativeTo: node)
                    return center.y < rootBounds.min.y + rootHeight * 0.42
                }
                lavaParts = fallbackLava
            }

            print("WWF AR crater asset nodes: \(geometryNodes(in: node).count), opening parts: \(openingParts.count), lava parts: \(lavaParts.count)")
            return CraterParts(opening: openingParts, lava: lavaParts)
        }

        private enum CraterGeometryRole {
            case lava
            case openingCap
            case rock
        }

        private func craterRole(
            for child: SCNNode,
            root: SCNNode,
            rootBounds: (min: SCNVector3, max: SCNVector3),
            rootCenter: SCNVector3,
            rootFootprint: Float,
            rootHeight: Float
        ) -> CraterGeometryRole {
            let childBounds = child.boundingBox
            let childWidth = childBounds.max.x - childBounds.min.x
            let childHeight = childBounds.max.y - childBounds.min.y
            let childDepth = childBounds.max.z - childBounds.min.z
            let childFootprint = max(childWidth, childDepth)
            let center = centerOfNode(child, relativeTo: root)
            let normalizedY = (center.y - rootBounds.min.y) / rootHeight
            let distanceFromCenter = hypot(center.x - rootCenter.x, center.z - rootCenter.z)

            let isLowerInterior = normalizedY < 0.38 && distanceFromCenter < rootFootprint * 0.36
            let isFlatPlatform = childHeight < rootHeight * 0.18 && childFootprint > rootFootprint * 0.16
            if isLowerInterior || (isFlatPlatform && normalizedY < 0.46 && distanceFromCenter < rootFootprint * 0.42) {
                return .lava
            }

            let isBroadCap = childFootprint > rootFootprint * 0.18 || childHeight < rootHeight * 0.28
            let isNearTop = normalizedY > 0.42
            let isNotFarRim = distanceFromCenter < rootFootprint * 0.46
            if isBroadCap && isNearTop && isNotFarRim {
                return .openingCap
            }

            let loweredName = (child.name ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if loweredName.contains("lava") || loweredName.contains("magma") || loweredName.contains("white") || loweredName.contains("bianco") {
                return .lava
            }

            return .rock
        }

        private func geometryNodes(in node: SCNNode) -> [SCNNode] {
            var nodes: [SCNNode] = []
            node.enumerateHierarchy { child, _ in
                if child.geometry != nil {
                    nodes.append(child)
                }
            }
            return nodes
        }

        private func centerOfNode(_ child: SCNNode, relativeTo root: SCNNode) -> SCNVector3 {
            let bounds = child.boundingBox
            let localCenter = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                (bounds.min.z + bounds.max.z) / 2
            )
            return child.convertPosition(localCenter, to: root)
        }

        private func applyLavaMaterial(_ material: SCNMaterial) {
            let texture = makeLavaTexture()
            material.lightingModel = .constant
            material.diffuse.contents = texture
            material.diffuse.magnificationFilter = .linear
            material.diffuse.minificationFilter = .linear
            material.diffuse.mipFilter = .linear
            material.selfIllumination.contents = texture
            material.selfIllumination.intensity = 0.72
            material.emission.contents = UIColor(red: 0.70, green: 0.12, blue: 0.025, alpha: 1)
            material.roughness.contents = 0.24
            material.metalness.contents = 0.0
        }

        private func applyBasaltMaterial(_ material: SCNMaterial) {
            material.lightingModel = .physicallyBased
            material.diffuse.contents = makeBasaltTexture()
            material.emission.contents = UIColor(red: 0.075, green: 0.055, blue: 0.04, alpha: 1)
            material.roughness.contents = 0.84
            material.metalness.contents = 0.0
        }

        private func playCraterReveal(on node: SCNNode, craterParts: CraterParts) {
            let finalScale = node.scale
            node.scale = SCNVector3(finalScale.x * 0.86, finalScale.y * 0.86, finalScale.z * 0.86)
            let settle = SCNAction.customAction(duration: 1.2) { node, elapsed in
                let t = Float(min(max(elapsed / 1.2, 0), 1))
                let eased = 1 - pow(1 - t, 3)
                let scale = 0.86 + (1.0 - 0.86) * eased
                node.scale = SCNVector3(finalScale.x * scale, finalScale.y * scale, finalScale.z * scale)
            }
            node.runAction(settle, forKey: "wwf.crater.asset-reveal")
            openCraterParts(craterParts.opening, in: node)
            node.runAction(.sequence([
                .wait(duration: 1.85),
                .run { [weak self] root in
                    self?.raiseLavaPlatform(craterParts.lava, in: root)
                }
            ]), forKey: "wwf.crater.delayed-lava-eruption")
        }

        private func openCraterParts(_ parts: [SCNNode], in root: SCNNode) {
            guard !parts.isEmpty else {
                addSingleMeshDeformationFallback(to: root)
                return
            }

            let bounds = root.boundingBox
            let rootCenter = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                (bounds.min.z + bounds.max.z) / 2
            )
            let footprint = max(bounds.max.x - bounds.min.x, bounds.max.z - bounds.min.z)
            let lift = CGFloat(footprint * 0.035)
            let spread = CGFloat(footprint * 0.12)

            for (index, part) in parts.enumerated() {
                let center = centerOfNode(part, relativeTo: root)
                var dx = center.x - rootCenter.x
                var dz = center.z - rootCenter.z
                let length = max(hypot(dx, dz), 0.001)
                dx /= length
                dz /= length

                let move = SCNAction.moveBy(x: CGFloat(dx) * spread, y: lift, z: CGFloat(dz) * spread, duration: 1.8)
                move.timingMode = .easeInEaseOut

                let directionSign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                let tilt = SCNAction.rotateBy(x: CGFloat(dz) * 0.28, y: directionSign * 0.05, z: -CGFloat(dx) * 0.28, duration: 1.8)
                tilt.timingMode = .easeInEaseOut

                part.runAction(.group([move, tilt]), forKey: "wwf.crater.open-cap")
            }
        }

        private func raiseLavaPlatform(_ lavaParts: [SCNNode], in root: SCNNode) {
            guard !lavaParts.isEmpty else { return }

            let bounds = root.boundingBox
            let width = bounds.max.x - bounds.min.x
            let height = max(bounds.max.y - bounds.min.y, 0.001)
            let depth = bounds.max.z - bounds.min.z
            let footprint = max(width, depth)

            let lift = CGFloat(height * 0.54)
            for lava in lavaParts {
                let initialPosition = lava.position
                let initialScale = lava.scale
                let erupt = SCNAction.customAction(duration: 3.4) { lavaNode, elapsed in
                    let progress = Float(min(max(elapsed / 3.4, 0), 1))
                    let eased = progress * progress * (3 - 2 * progress)
                    lavaNode.position = SCNVector3(
                        initialPosition.x,
                        initialPosition.y + Float(lift) * eased,
                        initialPosition.z
                    )
                    lavaNode.scale = SCNVector3(
                        initialScale.x * (1 + 0.06 * eased),
                        initialScale.y * (1 + 0.72 * eased),
                        initialScale.z * (1 + 0.06 * eased)
                    )
                }
                let breathe = SCNAction.repeatForever(.sequence([
                    .moveBy(x: 0, y: CGFloat(height * 0.026), z: 0, duration: 1.05),
                    .moveBy(x: 0, y: -CGFloat(height * 0.026), z: 0, duration: 1.05)
                ]))
                lava.runAction(.sequence([erupt, breathe]), forKey: "wwf.crater.existing-lava-rise")
            }

            let light = SCNLight()
            light.type = .omni
            light.color = UIColor(red: 1.0, green: 0.22, blue: 0.02, alpha: 1)
            light.intensity = 430
            light.attenuationEndDistance = CGFloat(footprint * 0.85)
            let lightNode = SCNNode()
            lightNode.light = light
            lightNode.position = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                bounds.min.y + height * 0.48,
                (bounds.min.z + bounds.max.z) / 2
            )
            root.addChildNode(lightNode)
        }

        private func addSingleMeshDeformationFallback(to root: SCNNode) {
            root.enumerateHierarchy { child, _ in
                guard let geometry = child.geometry else { return }
                geometry.shaderModifiers = [
                    .geometry: """
                    #pragma body
                    float radius = length(_geometry.position.xz);
                    float openMask = smoothstep(0.02, 0.34, radius);
                    float timeMask = min(u_time / 2.0, 1.0);
                    _geometry.position.y += openMask * timeMask * 0.035;
                    _geometry.position.xz += normalize(_geometry.position.xz + float2(0.0001, 0.0001)) * openMask * timeMask * 0.055;
                    """
                ]
            }
        }

        private func materialLooksLikeLavaCandidate(_ material: SCNMaterial) -> Bool {
            if let color = material.diffuse.contents as? UIColor {
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
                let looksWhite = red > 0.78 && green > 0.78 && blue > 0.78
                let looksWarm = red > 0.75 && green > 0.18 && green < 0.55 && blue < 0.25
                return alpha > 0.45 && (looksWhite || looksWarm)
            }

            if material.diffuse.contents is UIImage {
                return materialNameLooksLikeLava(material)
            }

            if let url = material.diffuse.contents as? URL {
                let lowered = url.lastPathComponent.lowercased()
                return lowered.contains("lava") || lowered.contains("magma") || lowered.contains("white") || lowered.contains("bianco")
            }

            if let name = material.diffuse.contents as? String {
                let lowered = name.lowercased()
                return lowered.contains("lava") || lowered.contains("magma") || lowered.contains("white") || lowered.contains("bianco")
            }

            return false
        }

        private func materialNameLooksLikeLava(_ material: SCNMaterial) -> Bool {
            let lowered = (material.name ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return lowered.contains("lava") ||
                lowered.contains("magma") ||
                lowered.contains("white") ||
                lowered.contains("bianco") ||
                lowered.contains("flow")
        }

        private func pulseMaterial(_ material: SCNMaterial) {
            let low = UIColor(red: 0.75, green: 0.10, blue: 0.01, alpha: 1)
            let high = UIColor(red: 1.0, green: 0.43, blue: 0.04, alpha: 1)
            let fadeUp = CABasicAnimation(keyPath: "emission.contents")
            fadeUp.fromValue = low.cgColor
            fadeUp.toValue = high.cgColor
            fadeUp.duration = 1.8
            fadeUp.autoreverses = true
            fadeUp.repeatCount = .greatestFiniteMagnitude
            fadeUp.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            material.addAnimation(fadeUp, forKey: "wwf.lava.material-breath")
        }

        private func makeLavaTexture() -> UIImage {
            let size = CGSize(width: 512, height: 512)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                drawLavaNoise(in: context.cgContext, size: size)
                drawLavaCrustLines(size: size)
                drawLavaDarkBorder(size: size)
            }
        }

        private func drawLavaNoise(in cgContext: CGContext, size: CGSize) {
            UIColor(red: 0.12, green: 0.012, blue: 0.0, alpha: 1).setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            let cell = CGFloat(2)
            let centerX = size.width / 2
            let centerY = size.height / 2
            for y in stride(from: CGFloat(0), to: size.height, by: cell) {
                for x in stride(from: CGFloat(0), to: size.width, by: cell) {
                    let normalizedX = (x - centerX) / centerX
                    let normalizedY = (y - centerY) / centerY
                    let radius = min(sqrt(normalizedX * normalizedX + normalizedY * normalizedY), 1)
                    let noise = fract(sin(x * 12.9898 + y * 78.233) * 43758.5453)
                    let lowNoise = fract(sin(x * 3.17 + y * 5.91) * 12831.371)
                    let veinWave = sin(x * 0.030 + y * 0.021 + lowNoise * 2.2)
                    let secondaryWave = sin(x * 0.013 - y * 0.026 + noise * 1.7)
                    let vein = max(0, 1 - abs(veinWave) * 2.9)
                    let slowFold = max(0, 1 - abs(secondaryWave) * 2.2)
                    let heat = min(max(vein * 0.64 + slowFold * 0.26 + noise * 0.12 + (1 - radius) * 0.18, 0), 1)
                    let crust = smoothstep(0.50, 0.96, radius)
                    let red = max(0.08, min(0.16 + heat * 0.74 - crust * 0.12, 0.96))
                    let green = max(0.012, min(0.026 + heat * 0.30 - crust * 0.055, 0.42))
                    let blue = max(0.0, min(0.004 + heat * 0.030, 0.065))
                    cgContext.setFillColor(UIColor(red: red, green: green, blue: blue, alpha: 1).cgColor)
                    cgContext.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
        }

        private func drawLavaCrustLines(size: CGSize) {
            UIColor(red: 0.018, green: 0.014, blue: 0.010, alpha: 0.44).setStroke()
            for y in stride(from: CGFloat(24), through: size.height - 18, by: CGFloat(38)) {
                let path = UIBezierPath()
                path.lineWidth = 3
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width, y: y + 16),
                    controlPoint1: CGPoint(x: size.width * 0.28, y: y - 36),
                    controlPoint2: CGPoint(x: size.width * 0.66, y: y + 48)
                )
                path.stroke()
            }

            UIColor(red: 0.98, green: 0.30, blue: 0.045, alpha: 0.28).setStroke()
            for y in stride(from: CGFloat(60), through: size.height - 38, by: CGFloat(96)) {
                let path = UIBezierPath()
                path.lineWidth = 7
                path.lineCapStyle = .round
                path.move(to: CGPoint(x: 24, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width - 18, y: y - 6),
                    controlPoint1: CGPoint(x: size.width * 0.24, y: y + 46),
                    controlPoint2: CGPoint(x: size.width * 0.58, y: y - 56)
                )
                path.stroke()
            }
        }

        private func drawLavaDarkBorder(size: CGSize) {
            UIColor(red: 0.010, green: 0.008, blue: 0.006, alpha: 0.48).setStroke()
            for inset in stride(from: CGFloat(4), through: CGFloat(48), by: CGFloat(14)) {
                let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
                let path = UIBezierPath(ovalIn: rect)
                path.lineWidth = 9
                path.stroke()
            }
        }

        private func fract(_ value: CGFloat) -> CGFloat {
            value - floor(value)
        }

        private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
            let x = min(max((value - edge0) / (edge1 - edge0), 0), 1)
            return x * x * (3 - 2 * x)
        }

        private func makeBasaltTexture() -> UIImage {
            let size = CGSize(width: 256, height: 256)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor(red: 0.115, green: 0.095, blue: 0.075, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                for _ in 0..<180 {
                    let shade = CGFloat.random(in: 0.10...0.34)
                    UIColor(red: shade, green: shade * 0.86, blue: shade * 0.72, alpha: CGFloat.random(in: 0.22...0.78)).setFill()
                    context.cgContext.fillEllipse(in: CGRect(
                        x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height),
                        width: CGFloat.random(in: 3...32),
                        height: CGFloat.random(in: 2...18)
                    ))
                }
            }
        }

    }
}

actor ARModelCache {
    static let shared = ARModelCache()

    private let fileManager = FileManager.default

    func localURL(for remoteURL: String) async throws -> URL {
        if remoteURL.hasPrefix("/"), fileManager.fileExists(atPath: remoteURL) {
            return URL(fileURLWithPath: remoteURL)
        }

        let cacheDirectory = try cacheDirectory()
        let fileName = cacheFileName(for: remoteURL)
        let destination = cacheDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

        let data = try await SupabaseConfig.shared.downloadFile(from: remoteURL)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func cacheDirectory() throws -> URL {
        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ARModels", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func cacheFileName(for remoteURL: String) -> String {
        guard let data = remoteURL.data(using: .utf8) else {
            return "\(UUID().uuidString).usdz"
        }
        let hash = data.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
        return "\(hash).usdz"
    }
}
