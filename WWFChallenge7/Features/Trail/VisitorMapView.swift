import SwiftUI
import UIKit
internal import _LocationEssentials

// MARK: - VisitorMapView (UIScrollView wrapper)

/// Utilizza lo stesso approccio basato su UIScrollView del MapEditorView del manager
/// per garantire un allineamento perfetto dei POI. I marker scalano dinamicamente con lo zoom,
/// i percorsi (trail paths) sono disegnati nello spazio coordinate dell'immagine e
/// l'indicatore di posizione dell'utente pulsa correttamente.
struct VisitorMapView: UIViewRepresentable {
    let trail: Trail
    let completedPOIIds: Set<UUID>
    let currentStepPOIId: UUID?
    let currentNormalizedPosition: CGPoint
    let navigationState: TrailNavigationState
    var isDashboard: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .normal
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0

        if isDashboard {
            scrollView.contentInset = .zero
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 40, left: 20, bottom: 320, right: 20)
        }

        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        context.coordinator.containerView = container
        scrollView.addSubview(container)

        var mapImageViews: [UIImageView] = []
        var loadedPieces: [UIImage] = []
        var missingPiece = false

        for i in 1...7 {
            if let piece = UIImage(named: "astroni_map_piece_\(i)") {
                loadedPieces.append(piece)
            } else {
                missingPiece = true
                break
            }
        }

        let isUsingPieces: Bool

        if !missingPiece && loadedPieces.count == 7 {
            isUsingPieces = true
            for piece in loadedPieces {
                let imageView = UIImageView(image: piece)
                imageView.contentMode = .scaleToFill
                imageView.isUserInteractionEnabled = false
                container.addSubview(imageView)
                mapImageViews.append(imageView)
            }
        } else {
            isUsingPieces = false
            if let fullMapImg = UIImage(named: "astroni_map") {
                let imageView = UIImageView(image: fullMapImg)
                imageView.contentMode = .scaleToFill
                imageView.isUserInteractionEnabled = false
                container.addSubview(imageView)
                mapImageViews.append(imageView)
            }
        }

        let baseImage = UIImage(named: "astroni_map") ?? UIImage(systemName: "map")

        context.coordinator.pieceImageViews = mapImageViews
        context.coordinator.baseImage = baseImage
        context.coordinator.isUsingPieces = isUsingPieces

        if let imgToUse = baseImage {
            DispatchQueue.main.async {
                context.coordinator.setupLayout(in: scrollView, image: imgToUse)
            }
        }

        scrollView.isAccessibilityElement = false
        scrollView.accessibilityLabel = "Mappa del percorso \(trail.localizedName)"
        container.isAccessibilityElement = false
        container.accessibilityContainerType = .semanticGroup

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self

        if !context.coordinator.isLayoutSetup, scrollView.bounds.width > 0, scrollView.bounds.height > 0 {
            if let imgToUse = context.coordinator.baseImage {
                context.coordinator.setupLayout(in: scrollView, image: imgToUse)
            }
        }

        context.coordinator.refreshMarkers(in: scrollView)
        context.coordinator.animateToCurrentPosition(in: scrollView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: VisitorMapView
        weak var containerView: UIView?
        var pieceImageViews: [UIImageView] = []
        var baseImage: UIImage?
        var isLayoutSetup = false
        var isUsingPieces = false
        private var hasAnimatedEntrance = false
        var lastTargetPosition: CGPoint?

        // Cached SwiftUI hosting controllers — created once, repositioned on zoom
        private var poiHostingControllers: [UUID: UIHostingController<MapsPOIMarker>] = [:]
        private var startMarkerHost: UIHostingController<AnyView>?

        init(_ parent: VisitorMapView) {
            self.parent = parent
        }

        // MARK: - Setup

        func setupLayout(in scrollView: UIScrollView, image: UIImage) {
            guard !isLayoutSetup else { return }
            guard let container = containerView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            guard screenW > 0, screenH > 0 else { return }

            isLayoutSetup = true

            let imageWidth = max(image.size.width, 1.0)
            let imgRatio = image.size.height / imageWidth
            let mapW = screenW
            let mapH = mapW * imgRatio

            container.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)

            for pieceView in pieceImageViews {
                pieceView.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            }

            scrollView.contentSize = CGSize(width: mapW, height: mapH)

            let scaleToFitH = screenH / mapH
            let scaleToFitW = screenW / mapW
            let fitScale = min(scaleToFitH, scaleToFitW)

            scrollView.minimumZoomScale = max(0.3, fitScale)
            scrollView.maximumZoomScale = 6.0

            if parent.isDashboard {
                let fillScale = max(scaleToFitH, scaleToFitW) * 0.85
                scrollView.zoomScale = fillScale
            } else {
                let initialZoom = min(max(fitScale * 2.0, 1.5), 3.0)
                scrollView.zoomScale = initialZoom
            }

            centerContent(in: scrollView)
            refreshMarkers(in: scrollView)
            animateToCurrentPosition(in: scrollView, force: true)
            animatePiecesEntrance(screenHeight: screenH)
        }

        func animatePiecesEntrance(screenHeight: CGFloat) {
            guard !hasAnimatedEntrance else { return }
            hasAnimatedEntrance = true

            for pieceView in pieceImageViews {
                pieceView.transform = .identity
                pieceView.alpha = 0.0
            }

            for (index, pieceView) in pieceImageViews.enumerated() {
                UIView.animate(
                    withDuration: 0.8,
                    delay: Double(index) * 0.35,
                    options: [.curveEaseOut, .allowUserInteraction],
                    animations: { pieceView.alpha = 1.0 },
                    completion: nil
                )
            }
        }

        // MARK: - UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
            refreshMarkers(in: scrollView)
        }

        // MARK: - Layout

        private func centerContent(in scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = container.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0
            } else {
                frameToCenter.origin.x = 0
            }

            if parent.isDashboard {
                if frameToCenter.size.height < boundsSize.height {
                    frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) * 0.35
                } else {
                    frameToCenter.origin.y = 0
                }
            } else {
                let bottomOverlayHeight: CGFloat = 200
                let visibleHeight = max(0, boundsSize.height - bottomOverlayHeight)
                if frameToCenter.size.height < visibleHeight {
                    frameToCenter.origin.y = (visibleHeight - frameToCenter.size.height) / 2.0
                } else {
                    frameToCenter.origin.y = 0
                }
            }

            container.frame = frameToCenter
        }

        func animateToCurrentPosition(in scrollView: UIScrollView, force: Bool = false) {
            if parent.isDashboard {
                let contentSize = scrollView.contentSize
                let boundsSize = scrollView.bounds.size
                let offsetX = max(0, (contentSize.width - boundsSize.width) / 2)
                let offsetY = max(0, ((contentSize.height - boundsSize.height) / 2) + 120)
                scrollView.setContentOffset(CGPoint(x: offsetX, y: offsetY), animated: !force)
                return
            }

            let newPos = parent.currentNormalizedPosition
            if !force, let lastPos = lastTargetPosition, lastPos == newPos { return }
            lastTargetPosition = newPos

            guard let container = containerView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            let currentScale = scrollView.zoomScale
            let mapW = container.bounds.width
            let mapH = container.bounds.height

            let cx = newPos.x * mapW
            let cy = newPos.y * mapH

            let insets = scrollView.contentInset
            let totalContentW = mapW * currentScale
            let totalContentH = mapH * currentScale
            let minOffsetX = -insets.left
            let minOffsetY = -insets.top
            let maxOffsetX = max(minOffsetX, totalContentW - screenW + insets.right)
            let maxOffsetY = max(minOffsetY, totalContentH - screenH + insets.bottom)

            let bottomPanel: CGFloat = 200
            let visibleCenterY = (screenH - bottomPanel) / 2

            let offsetX = max(minOffsetX, min(cx * currentScale - screenW / 2, maxOffsetX))
            let offsetY = max(minOffsetY, min(cy * currentScale - visibleCenterY, maxOffsetY))
            let targetOffset = CGPoint(x: offsetX, y: offsetY)

            if force {
                scrollView.setContentOffset(targetOffset, animated: false)
            } else {
                UIView.animate(
                    withDuration: 1.0, delay: 0,
                    usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2,
                    options: .curveEaseInOut
                ) {
                    scrollView.setContentOffset(targetOffset, animated: false)
                }
            }
        }

        // MARK: - Refresh Markers

        func refreshMarkers(in scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let imageSize = container.bounds.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let currentScale = scrollView.zoomScale

            // Remove path layers and user dot — hosted marker views are kept
            container.layer.sublayers?
                .filter { layer in
                    layer !== container.layer &&
                    !self.pieceImageViews.contains(where: { $0.layer === layer }) &&
                    !self.poiHostingControllers.values.contains(where: { $0.view.layer === layer }) &&
                    layer !== self.startMarkerHost?.view.layer
                }
                .forEach { $0.removeFromSuperlayer() }

            container.subviews
                .filter { subview in
                    !self.pieceImageViews.contains(where: { $0 === subview }) &&
                    !self.poiHostingControllers.values.contains(where: { $0.view === subview }) &&
                    subview !== self.startMarkerHost?.view
                }
                .forEach { $0.removeFromSuperview() }

            // 1. Trail path — drawn first so it sits below everything
            drawTrailPath(in: container, imageSize: imageSize)

            // 2. User location — below markers but above path
            drawUserIndicator(in: container, imageSize: imageSize, zoomScale: currentScale)

            // 3. Start marker — brought to front after path layers
            drawStartMarker(in: container, imageSize: imageSize, zoomScale: currentScale)

            // 4. POI markers — brought to front last so they're always on top
            for step in parent.trail.sortedSteps {
                guard let poi = step.poi else { continue }
                drawPOIMarker(
                    poi: poi,
                    in: container,
                    imageSize: imageSize,
                    zoomScale: currentScale,
                    isCompleted: parent.completedPOIIds.contains(poi.id),
                    isCurrent: poi.id == parent.currentStepPOIId
                )
            }
        }

        // MARK: - Trail Path

        private func drawTrailPath(in container: UIView, imageSize: CGSize) {
            let sortedSteps = parent.trail.sortedSteps
            guard !sortedSteps.isEmpty else { return }

            for (index, step) in sortedSteps.enumerated() {
                let isCompleted = parent.completedPOIIds.contains(step.poi?.id ?? UUID())
                let isNextActive = step.poi?.id == parent.currentStepPOIId

                var points: [CGPoint] = []

                if let geom = step.pathGeometry, !geom.isEmpty {
                    let coords = PolylineCodec.decode(geom)
                    points = coords.map { CGPoint(x: $0.latitude * imageSize.width, y: $0.longitude * imageSize.height) }
                } else {
                    let startPoint: CGPoint
                    if index == 0 {
                        startPoint = CGPoint(
                            x: parent.trail.startX * imageSize.width,
                            y: parent.trail.startY * imageSize.height
                        )
                    } else {
                        let prevPOI = sortedSteps[index - 1].poi
                        startPoint = CGPoint(
                            x: (prevPOI?.x ?? 0) * imageSize.width,
                            y: (prevPOI?.y ?? 0) * imageSize.height
                        )
                    }
                    let endPoint = CGPoint(
                        x: (step.poi?.x ?? 0) * imageSize.width,
                        y: (step.poi?.y ?? 0) * imageSize.height
                    )
                    points = [startPoint, endPoint]
                }

                guard points.count >= 2 else { continue }

                let path = UIBezierPath()
                if let first = points.first {
                    path.move(to: first)
                    for i in 1..<points.count { path.addLine(to: points[i]) }
                }

                let pathLayer = CAShapeLayer()
                pathLayer.path = path.cgPath
                pathLayer.fillColor = nil
                pathLayer.lineJoin = .round
                pathLayer.lineCap = .round

                if isCompleted {
                    pathLayer.strokeColor = UIColor.gray.withAlphaComponent(0.3).cgColor
                    pathLayer.lineWidth = 2
                    pathLayer.lineDashPattern = nil
                } else if isNextActive {
                    let green = UIColor(WWFDesign.Colors.forestLight)
                    pathLayer.strokeColor = green.cgColor
                    pathLayer.lineWidth = 6
                    pathLayer.lineDashPattern = nil
                    pathLayer.shadowColor = green.cgColor
                    pathLayer.shadowRadius = 6
                    pathLayer.shadowOpacity = 0.8
                    pathLayer.shadowOffset = .zero
                } else {
                    pathLayer.strokeColor = UIColor(WWFDesign.Colors.forestLight).withAlphaComponent(0.8).cgColor
                    pathLayer.lineWidth = 3
                    pathLayer.lineDashPattern = [4, 4]
                }

                container.layer.addSublayer(pathLayer)
            }
        }

        // MARK: - Start Marker

        private func drawStartMarker(in container: UIView, imageSize: CGSize, zoomScale: CGFloat) {
            let cx = parent.trail.startX * imageSize.width
            let cy = parent.trail.startY * imageSize.height

            let isAtStart: Bool = {
                if case .atStart = parent.navigationState { return true }
                return false
            }()

            let pinW: CGFloat = 42 / zoomScale
            let pinH: CGFloat = 56 / zoomScale

            if startMarkerHost == nil {
                let host = UIHostingController(rootView: AnyView(
                    MapsPinShape(
                        fillColor: Color(UIColor(named: "WWFGreen") ?? .green),
                        iconName: "flag.fill",
                        iconColor: .white
                    )
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
                ))
                host.view.backgroundColor = .clear
                container.addSubview(host.view)
                startMarkerHost = host

                host.view.isAccessibilityElement = true
                host.view.accessibilityLabel = "Punto di partenza: \(parent.trail.startPointName)"
                host.view.accessibilityTraits = .staticText
            }

            let highlightOffset: CGFloat = isAtStart ? 7 / zoomScale : 0
            startMarkerHost?.view.frame = CGRect(
                x: cx - pinW / 2,
                y: cy - pinH - highlightOffset,
                width: pinW,
                height: pinH
            )

            // Always above path layers
            if let view = startMarkerHost?.view {
                container.bringSubviewToFront(view)
            }
        }

        // MARK: - POI Marker

        private func drawPOIMarker(
            poi: POI,
            in container: UIView,
            imageSize: CGSize,
            zoomScale: CGFloat,
            isCompleted: Bool,
            isCurrent: Bool
        ) {
            let cx = poi.x * imageSize.width
            let cy = poi.y * imageSize.height

            let pinW: CGFloat = 42 / zoomScale
            let pinH: CGFloat = 56 / zoomScale
            let highlightOffset: CGFloat = isCurrent ? 8 / zoomScale : 0

            let frame = CGRect(
                x: cx - pinW / 2,
                y: cy - pinH - highlightOffset,
                width: pinW,
                height: pinH
            )

            if let host = poiHostingControllers[poi.id] {
                host.rootView = MapsPOIMarker(poi: poi, isCompleted: isCompleted, isCurrent: isCurrent)
                host.view.frame = frame
            } else {
                let host = UIHostingController(rootView:
                    MapsPOIMarker(poi: poi, isCompleted: isCompleted, isCurrent: isCurrent)
                )
                host.view.backgroundColor = .clear
                host.view.frame = frame
                container.addSubview(host.view)
                poiHostingControllers[poi.id] = host

                host.view.isAccessibilityElement = true
                host.view.accessibilityLabel = "\(poi.localizedName), \(isCompleted ? "completato" : isCurrent ? "prossima tappa" : "da visitare")"
                host.view.accessibilityTraits = .button
            }

            // Always above path layers — current pin goes last so it's topmost
            if let host = poiHostingControllers[poi.id] {
                container.bringSubviewToFront(host.view)
            }
        }

        // MARK: - User Location Indicator

        private func drawUserIndicator(in container: UIView, imageSize: CGSize, zoomScale: CGFloat) {
            let pos = parent.currentNormalizedPosition
            let cx = pos.x * imageSize.width
            let cy = pos.y * imageSize.height

            let dotSize: CGFloat = 16 / zoomScale
            let pulseSize: CGFloat = 40 / zoomScale

            let userView = UIView(frame: CGRect(
                x: cx - pulseSize / 2,
                y: cy - pulseSize / 2,
                width: pulseSize,
                height: pulseSize
            ))
            userView.backgroundColor = .clear

            // Pulse ring
            let pulseRing = CALayer()
            pulseRing.bounds = CGRect(x: 0, y: 0, width: pulseSize, height: pulseSize)
            pulseRing.position = CGPoint(x: pulseSize / 2, y: pulseSize / 2)
            pulseRing.cornerRadius = pulseSize / 2
            pulseRing.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor

            let pulseAnim = CABasicAnimation(keyPath: "transform.scale")
            pulseAnim.fromValue = 1.0
            pulseAnim.toValue = 1.4
            pulseAnim.duration = 1.4
            pulseAnim.repeatCount = .infinity
            pulseAnim.autoreverses = false

            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0.6
            fadeAnim.toValue = 0.0
            fadeAnim.duration = 1.4
            fadeAnim.repeatCount = .infinity

            let group = CAAnimationGroup()
            group.animations = [pulseAnim, fadeAnim]
            group.duration = 1.4
            group.repeatCount = .infinity
            pulseRing.add(group, forKey: "pulse")
            userView.layer.addSublayer(pulseRing)

            // Blue dot
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
            dot.position = CGPoint(x: pulseSize / 2, y: pulseSize / 2)
            dot.cornerRadius = dotSize / 2
            dot.backgroundColor = UIColor.systemBlue.cgColor
            dot.borderColor = UIColor.white.cgColor
            dot.borderWidth = 2 / zoomScale
            dot.shadowColor = UIColor.black.cgColor
            dot.shadowOffset = CGSize(width: 0, height: 1 / zoomScale)
            dot.shadowRadius = 3 / zoomScale
            dot.shadowOpacity = 0.4
            userView.layer.addSublayer(dot)

            container.addSubview(userView)
        }
    }
}
