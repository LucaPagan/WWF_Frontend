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
    var onCompletedPOITap: ((POI) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = UIColor(WWFDesign.Colors.backgroundCream)
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
        container.backgroundColor = UIColor(WWFDesign.Colors.backgroundCream)
        container.clipsToBounds = true
        context.coordinator.containerView = container
        scrollView.addSubview(container)

        var mapImageViews: [UIImageView] = []
        var loadedPieces: [UIImage] = []
        var missingPiece = false
        
        for i in 0...38{
            if let piece = UIImage(named: "astroni_map_piece_\(i)") {
                loadedPieces.append(piece)
            } else {
                missingPiece = true
                break
            }
        }

        let isUsingPieces: Bool
        
        if !missingPiece && loadedPieces.count == 39 {
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

        context.coordinator.resetDashboardViewportIfNeeded(in: scrollView)
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
        private var lastDashboardTrailId: UUID?

        // Cached SwiftUI hosting controllers — created once, repositioned on zoom
        private var poiHostingControllers: [UUID: UIHostingController<AnyView>] = [:]
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

            if parent.isDashboard {
                let dashboardFitScale = min(1.3, fitScale * 1.4)
                scrollView.minimumZoomScale = min(0.75, dashboardFitScale)
                scrollView.maximumZoomScale = 4.0
                scrollView.zoomScale = dashboardFitScale
            } else {
                scrollView.minimumZoomScale = max(0.3, fitScale)
                scrollView.maximumZoomScale = 6.0
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
                let topBarHeight: CGFloat = 165
                let bottomCardsReserve: CGFloat = 310
                let availableTop = min(topBarHeight, boundsSize.height * 0.32)
                let availableBottom = max(availableTop, boundsSize.height - bottomCardsReserve)
                let availableHeight = max(0, availableBottom - availableTop)

                if frameToCenter.size.height < availableHeight {
                    frameToCenter.origin.y = availableTop + (availableHeight - frameToCenter.size.height) / 2.0
                } else {
                    frameToCenter.origin.y = max(0, availableTop - (frameToCenter.size.height - availableHeight) / 2.0)
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

        func resetDashboardViewportIfNeeded(in scrollView: UIScrollView) {
            guard parent.isDashboard else { return }

            let trailId = parent.trail.id
            guard lastDashboardTrailId != trailId else { return }
            lastDashboardTrailId = trailId

            if let container = containerView, container.bounds.width > 0, container.bounds.height > 0 {
                let fitScale = min(
                    scrollView.bounds.height / container.bounds.height,
                    scrollView.bounds.width / container.bounds.width
                )
                let dashboardScale = min(1.3, fitScale * 1.4)
                scrollView.minimumZoomScale = min(0.75, dashboardScale)
                scrollView.zoomScale = dashboardScale
            }

            centerContent(in: scrollView)
            scrollView.setContentOffset(dashboardOverviewOffset(in: scrollView), animated: false)
        }

        func animateToCurrentPosition(in scrollView: UIScrollView, force: Bool = false) {
            if parent.isDashboard {
                centerContent(in: scrollView)
                scrollView.setContentOffset(dashboardOverviewOffset(in: scrollView), animated: false)
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

        private func dashboardOverviewOffset(in scrollView: UIScrollView) -> CGPoint {
            let horizontalOverflow = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let gentleLeftShift = scrollView.bounds.width * 0.065
            let offsetX = min(horizontalOverflow, gentleLeftShift)
            return CGPoint(x: offsetX, y: 0)
        }

        // MARK: - Refresh Markers

        func refreshMarkers(in scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let imageSize = container.bounds.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let currentScale = scrollView.zoomScale
            let visualSteps = visuallyDistinctMarkerSteps()
            let activePOIIds = Set(visualSteps.compactMap { $0.poi?.id })
            let stalePOIIds = poiHostingControllers.keys.filter { !activePOIIds.contains($0) }
            for poiId in stalePOIIds {
                poiHostingControllers[poiId]?.view.removeFromSuperview()
                poiHostingControllers.removeValue(forKey: poiId)
            }

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
            drawTrailPath(in: container, imageSize: imageSize, zoomScale: currentScale)

            // 2. User location — hidden on the Dashboard overview
            if !parent.isDashboard {
                drawUserIndicator(in: container, imageSize: imageSize, zoomScale: currentScale)
            }

            // 3. Start marker — brought to front after path layers
            drawStartMarker(in: container, imageSize: imageSize, zoomScale: currentScale)

            // 4. POI markers — brought to front last so they're always on top
            for step in visualSteps {
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

        // MARK: - Trail Path

        private func drawTrailPath(in container: UIView, imageSize: CGSize, zoomScale: CGFloat) {
            let sortedSteps = parent.trail.sortedSteps
            guard !sortedSteps.isEmpty else { return }

            for step in sortedSteps {
                let isCompleted = parent.completedPOIIds.contains(step.poi?.id ?? UUID())
                let isNextActive = step.poi?.id == parent.currentStepPOIId

                guard
                    let geom = step.pathGeometry?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !geom.isEmpty
                else { continue }

                let points = PolylineCodec.decode(geom).map {
                    CGPoint(x: $0.latitude * imageSize.width, y: $0.longitude * imageSize.height)
                }
                guard points.count >= 2 else { continue }

                let path = UIBezierPath()
                if let first = points.first {
                    path.move(to: first)
                    for i in 1..<points.count { path.addLine(to: points[i]) }
                }

                if isNextActive {
                    let green = UIColor(WWFDesign.Colors.forestLight)
                    let haloLayer = CAShapeLayer()
                    haloLayer.path = path.cgPath
                    haloLayer.fillColor = nil
                    haloLayer.strokeColor = green.withAlphaComponent(0.22).cgColor
                    haloLayer.lineWidth = 12 / zoomScale
                    haloLayer.lineJoin = .round
                    haloLayer.lineCap = .round
                    haloLayer.shadowColor = green.cgColor
                    haloLayer.shadowRadius = 10 / zoomScale
                    haloLayer.shadowOpacity = 0.54
                    haloLayer.shadowOffset = .zero
                    container.layer.addSublayer(haloLayer)
                }

                let pathLayer = CAShapeLayer()
                pathLayer.path = path.cgPath
                pathLayer.fillColor = nil
                pathLayer.lineJoin = .round
                pathLayer.lineCap = .round

                if isCompleted {
                    pathLayer.strokeColor = UIColor(WWFDesign.Colors.cardCream).withAlphaComponent(0.72).cgColor
                    pathLayer.lineWidth = 4 / zoomScale
                    pathLayer.lineDashPattern = nil
                    pathLayer.shadowColor = UIColor(WWFDesign.Colors.forestDark).cgColor
                    pathLayer.shadowRadius = 3 / zoomScale
                    pathLayer.shadowOpacity = 0.16
                    pathLayer.shadowOffset = .zero
                } else if isNextActive {
                    let green = UIColor(WWFDesign.Colors.forestLight)
                    pathLayer.strokeColor = green.cgColor
                    pathLayer.lineWidth = 5.5 / zoomScale
                    pathLayer.lineDashPattern = nil
                    pathLayer.shadowColor = green.cgColor
                    pathLayer.shadowRadius = 7 / zoomScale
                    pathLayer.shadowOpacity = 0.62
                    pathLayer.shadowOffset = .zero
                } else {
                    pathLayer.strokeColor = UIColor(WWFDesign.Colors.forestLight).withAlphaComponent(0.62).cgColor
                    pathLayer.lineWidth = 3.4 / zoomScale
                    pathLayer.lineDashPattern = [
                        NSNumber(value: Double(9 / zoomScale)),
                        NSNumber(value: Double(9 / zoomScale))
                    ]
                    pathLayer.shadowColor = UIColor(WWFDesign.Colors.forestDark).cgColor
                    pathLayer.shadowRadius = 2 / zoomScale
                    pathLayer.shadowOpacity = 0.12
                    pathLayer.shadowOffset = .zero
                }

                container.layer.addSublayer(pathLayer)

                if isNextActive {
                    drawWaypointDots(points: points, in: container, zoomScale: zoomScale)
                }
            }
        }

        private func drawWaypointDots(points: [CGPoint], in container: UIView, zoomScale: CGFloat) {
            guard points.count >= 2 else { return }
            let green = UIColor(WWFDesign.Colors.leafLight)
            var carry: CGFloat = 0
            let spacing: CGFloat = 52 / zoomScale
            let dotSize: CGFloat = 5.5 / zoomScale

            for index in 0..<(points.count - 1) {
                let from = points[index]
                let to = points[index + 1]
                let dx = to.x - from.x
                let dy = to.y - from.y
                let segmentLength = max(0.001, hypot(dx, dy))
                var distance = spacing - carry

                while distance < segmentLength {
                    let t = distance / segmentLength
                    let point = CGPoint(x: from.x + dx * t, y: from.y + dy * t)
                    let dot = CALayer()
                    dot.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
                    dot.position = point
                    dot.cornerRadius = dotSize / 2
                    dot.backgroundColor = UIColor.white.withAlphaComponent(0.92).cgColor
                    dot.borderColor = green.withAlphaComponent(0.86).cgColor
                    dot.borderWidth = 1.2 / zoomScale
                    dot.shadowColor = green.cgColor
                    dot.shadowRadius = 5 / zoomScale
                    dot.shadowOpacity = 0.58
                    dot.shadowOffset = .zero
                    container.layer.addSublayer(dot)
                    distance += spacing
                }

                carry = segmentLength.truncatingRemainder(dividingBy: spacing)
            }
        }

        // MARK: - Start Marker

        private func drawStartMarker(in container: UIView, imageSize: CGSize, zoomScale: CGFloat) {
            let cx = parent.trail.startX * imageSize.width
            let cy = parent.trail.startY * imageSize.height

            let pinW: CGFloat = 42 / zoomScale
            let pinH: CGFloat = 56 / zoomScale

            if startMarkerHost == nil {
                let host = UIHostingController(rootView: AnyView(
                    MapsPinShape(
                        fillColor: Color(UIColor(named: "WWFGreen") ?? .green),
                        iconName: "flag.fill",
                        iconColor: WWFDesign.Colors.forestDark
                    )
                    .shadow(color: WWFDesign.Colors.forestDark.opacity(0.24), radius: 4, x: 0, y: 3)
                ))
                host.view.backgroundColor = .clear
                container.addSubview(host.view)
                startMarkerHost = host

                host.view.isAccessibilityElement = true
                host.view.accessibilityLabel = "Punto di partenza: \(parent.trail.startPointName)"
                host.view.accessibilityTraits = .staticText
            }

            startMarkerHost?.view.frame = CGRect(
                x: cx - pinW / 2,
                y: cy - pinH,
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

            let frame = CGRect(
                x: cx - pinW / 2,
                y: cy - pinH,
                width: pinW,
                height: pinH
            )

            if let host = poiHostingControllers[poi.id] {
                host.rootView = markerView(for: poi, isCompleted: isCompleted, isCurrent: isCurrent)
                host.view.frame = frame
            } else {
                let host = UIHostingController(rootView:
                    markerView(for: poi, isCompleted: isCompleted, isCurrent: isCurrent)
                )
                host.view.backgroundColor = .clear
                host.view.frame = frame
                container.addSubview(host.view)
                poiHostingControllers[poi.id] = host

                host.view.isAccessibilityElement = true
                host.view.accessibilityLabel = "\(poi.localizedName), \(isCompleted ? "completato" : isCurrent ? "prossima tappa" : "da visitare")"
                host.view.accessibilityTraits = isCompleted ? .button : .staticText
            }

            // Always above path layers — current pin goes last so it's topmost
            if let host = poiHostingControllers[poi.id] {
                container.bringSubviewToFront(host.view)
            }
        }

        private func markerView(for poi: POI, isCompleted: Bool, isCurrent: Bool) -> AnyView {
            AnyView(MapsPOIMarker(poi: poi, isCompleted: isCompleted, isCurrent: isCurrent)
                .contentShape(Rectangle())
                .onTapGesture { [self] in
                    guard isCompleted else { return }
                    parent.onCompletedPOITap?(poi)
                })
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
            dot.shadowColor = UIColor(WWFDesign.Colors.forestDark).cgColor
            dot.shadowOffset = CGSize(width: 0, height: 1 / zoomScale)
            dot.shadowRadius = 3 / zoomScale
            dot.shadowOpacity = 0.18
            userView.layer.addSublayer(dot)

            container.addSubview(userView)
        }
    }
}
