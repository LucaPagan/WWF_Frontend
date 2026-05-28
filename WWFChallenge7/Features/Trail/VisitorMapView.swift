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
        
        // Add content insets so the user can pan the map freely past the edges.
        // The bottom inset is large to account for the navigation card overlay.
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

        // Accessibility: label the map for VoiceOver
        scrollView.isAccessibilityElement = false
        scrollView.accessibilityLabel = "Mappa del percorso \(trail.localizedName)"
        container.isAccessibilityElement = false
        container.accessibilityContainerType = .semanticGroup

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        
        // If layout was not setup yet (e.g. because bounds were zero in makeUIView), set it up now!
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
        private var userDotLayer: CALayer?
        private var pulseLayer: CALayer?

        init(_ parent: VisitorMapView) {
            self.parent = parent
        }

        func setupLayout(in scrollView: UIScrollView, image: UIImage) {
            guard !isLayoutSetup else { return }
            guard let container = containerView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            
            // Only proceed if we have valid dimensions
            guard screenW > 0, screenH > 0 else { return }
            isLayoutSetup = true
            let imageWidth = max(image.size.width, 1.0)
            let imgRatio = image.size.height / imageWidth

            let mapW = screenW
            let mapH = mapW * imgRatio

            container.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            
            // Set frame for map image view(s) — always full size, matching container
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
                // Dashboard: fill the screen height, showing the map centered
                let fillScale = max(scaleToFitH, scaleToFitW) * 0.85
                scrollView.zoomScale = fillScale
            } else {
                // Navigation: comfortable initial zoom (2x the fit scale, capped at 3.0)
                let initialZoom = min(max(fitScale * 2.0, 1.5), 3.0)
                scrollView.zoomScale = initialZoom
            }

            centerContent(in: scrollView)
            refreshMarkers(in: scrollView)
            animateToCurrentPosition(in: scrollView, force: true)
            
            // Smooth entrance animation
            animatePiecesEntrance(screenHeight: screenH)
        }

        func animatePiecesEntrance(screenHeight: CGFloat) {
            guard !hasAnimatedEntrance else { return }
            hasAnimatedEntrance = true

            // Set initial state: transforms are identity to prevent layout alignment corruption if canceled, alpha is transparent
            for pieceView in pieceImageViews {
                pieceView.transform = .identity
                pieceView.alpha = 0.0
            }

            // Animate each piece fade-in sequentially for a premium staggered composition effect
            for (index, pieceView) in pieceImageViews.enumerated() {
                let delay = Double(index) * 0.35
                
                UIView.animate(
                    withDuration: 0.8,
                    delay: delay,
                    options: [.curveEaseOut, .allowUserInteraction],
                    animations: {
                        pieceView.alpha = 1.0
                    },
                    completion: nil
                )
            }
        }

        // MARK: UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
            refreshMarkers(in: scrollView)
        }

        private func centerContent(in scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = container.frame

            // Horizontal centering: if content is narrower than screen, center it
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0
            } else {
                frameToCenter.origin.x = 0
            }

            // Vertical centering
            if parent.isDashboard {
                // Dashboard mode: center the map vertically in the full screen
                if frameToCenter.size.height < boundsSize.height {
                    frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) * 0.35
                } else {
                    frameToCenter.origin.y = 0
                }
            } else {
                // Navigation mode: offset for the bottom panel (~200px)
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
                // Dashboard: center the map content in the scroll view
                let contentSize = scrollView.contentSize
                let boundsSize = scrollView.bounds.size
                
                // Calculate offset to center content
                let offsetX = max(0, (contentSize.width - boundsSize.width) / 2)
                let offsetY = max(0, ((contentSize.height - boundsSize.height) / 2) + 120)
                
                scrollView.setContentOffset(CGPoint(x: offsetX, y: offsetY), animated: !force)
                return
            }

            let newPos = parent.currentNormalizedPosition
            if !force, let lastPos = lastTargetPosition, lastPos == newPos {
                return
            }
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
            
            // Offset the vertical center to account for the bottom navigation panel (~200px)
            let bottomPanel: CGFloat = 200
            let visibleCenterY = (screenH - bottomPanel) / 2
            
            let offsetX = max(minOffsetX, min(cx * currentScale - screenW / 2, maxOffsetX))
            let offsetY = max(minOffsetY, min(cy * currentScale - visibleCenterY, maxOffsetY))
            
            let targetOffset = CGPoint(x: offsetX, y: offsetY)
            
            if force {
                scrollView.setContentOffset(targetOffset, animated: false)
            } else {
                UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
                    scrollView.setContentOffset(targetOffset, animated: false)
                }
            }
        }

        // MARK: - Refresh all markers & overlays

        func refreshMarkers(in scrollView: UIScrollView) {
            guard let container = containerView else { return }

            let imageSize = container.bounds.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let currentScale = scrollView.zoomScale

            // Remove old overlays (except for map piece views)
            container.subviews
                .filter { subview in !self.pieceImageViews.contains(where: { $0 === subview }) }
                .forEach { $0.removeFromSuperview() }
            container.layer.sublayers?
                .filter { layer in
                    layer !== container.layer && !self.pieceImageViews.contains(where: { $0.layer === layer })
                }
                .forEach { $0.removeFromSuperlayer() }

            // 1. Draw trail path
            drawTrailPath(in: container, imageSize: imageSize)

            // 2. Draw start point marker
            drawStartMarker(in: container, imageSize: imageSize, zoomScale: currentScale)

            // 3. Draw POI markers
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

            // 4. Draw user location indicator
            drawUserIndicator(in: container, imageSize: imageSize, zoomScale: currentScale)
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
                    // Use the drawn path geometry
                    let coords = PolylineCodec.decode(geom)
                    points = coords.map { CGPoint(x: $0.latitude * imageSize.width, y: $0.longitude * imageSize.height) }
                } else {
                    // Fallback: straight line from previous POI (or start) to this POI
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
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }

                let pathLayer = CAShapeLayer()
                pathLayer.path = path.cgPath
                pathLayer.fillColor = nil
                pathLayer.lineJoin = .round
                pathLayer.lineCap = .round
                
                // Styling
                if isCompleted {
                    pathLayer.strokeColor = UIColor.gray.withAlphaComponent(0.3).cgColor
                    pathLayer.lineWidth = 2
                    pathLayer.lineDashPattern = nil
                } else if isNextActive {
                    // Current segment: Solid, thick, glowing green
                    let green = UIColor(WWFDesign.Colors.forestLight)
                    pathLayer.strokeColor = green.cgColor
                    pathLayer.lineWidth = 6
                    pathLayer.lineDashPattern = nil
                    
                    // Add subtle glow
                    pathLayer.shadowColor = green.cgColor
                    pathLayer.shadowRadius = 6
                    pathLayer.shadowOpacity = 0.8
                    pathLayer.shadowOffset = .zero
                } else {
                    // Future steps: Dotted line
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

            let diameter: CGFloat = 30 / zoomScale
            let pinTailExtra: CGFloat = diameter * 0.45  // Teardrop tail height

            let marker = VisitorMarkerUIView(
                diameter: diameter,
                fillColor: UIColor(named: "WWFGreen") ?? .green,
                iconName: "flag.fill",
                zoomScale: zoomScale,
                isHighlighted: isAtStart,
                label: parent.trail.startPointName
            )

            let totalW = max(diameter * 3, 80 / zoomScale)
            let labelH: CGFloat = 16 / zoomScale
            let gap: CGFloat = 4 / zoomScale
            let pinH = diameter + pinTailExtra
            let totalH = pinH + gap + labelH + (isAtStart ? 14 / zoomScale : 0)

            // Position so the pin tip points at the coordinate (cx, cy)
            marker.frame = CGRect(
                x: cx - totalW / 2,
                y: cy - pinH - (isAtStart ? 7 / zoomScale : 0),
                width: totalW,
                height: totalH
            )

            container.addSubview(marker)

            // UIKit accessibility for start marker
            marker.isAccessibilityElement = true
            marker.accessibilityLabel = "Punto di partenza: \(parent.trail.startPointName)"
            marker.accessibilityTraits = .staticText
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

            let diameter: CGFloat = 28 / zoomScale
            let pinTailExtra: CGFloat = diameter * 0.45  // Teardrop tail height

            let fillColor: UIColor = {
                if isCompleted { return .gray }
                if isCurrent { return .systemYellow }
                return UIColor(named: "WWFGreen") ?? .green
            }()

            let iconName = isCompleted ? "checkmark" : poi.type.icon

            let marker = VisitorMarkerUIView(
                diameter: diameter,
                fillColor: fillColor,
                iconName: iconName,
                zoomScale: zoomScale,
                isHighlighted: isCurrent,
                label: nil // Labels omitted on POI markers for a cleaner UI
            )

            let totalW = diameter * 2.5
            let pinH = diameter + pinTailExtra
            let totalH = pinH + (isCurrent ? 16 / zoomScale : 0)

            // Position so the pin tip points at the coordinate (cx, cy)
            marker.frame = CGRect(
                x: cx - totalW / 2,
                y: cy - pinH - (isCurrent ? 8 / zoomScale : 0),
                width: totalW,
                height: totalH
            )

            container.addSubview(marker)

            // UIKit accessibility for POI markers
            marker.isAccessibilityElement = true
            marker.accessibilityLabel = "\(poi.localizedName), \(isCompleted ? "completato" : isCurrent ? "prossima tappa" : "da visitare")"
            marker.accessibilityTraits = .button
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

// MARK: - VisitorMarkerUIView (Teardrop Pin — CoreGraphics rendering)

final class VisitorMarkerUIView: UIView {
    private let diameter: CGFloat
    private let fillColor: UIColor
    private let iconName: String
    private let zoomScale: CGFloat
    private let isHighlighted: Bool
    private let label: String?

    /// The total height of the teardrop pin (circle head + pointed tail).
    /// The tail adds ~40% of the diameter below the circle.
    private var pinTotalHeight: CGFloat { diameter + diameter * 0.45 }

    init(
        diameter: CGFloat,
        fillColor: UIColor,
        iconName: String,
        zoomScale: CGFloat,
        isHighlighted: Bool,
        label: String?
    ) {
        self.diameter = diameter
        self.fillColor = fillColor
        self.iconName = iconName
        self.zoomScale = zoomScale
        self.isHighlighted = isHighlighted
        self.label = label
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let circleCenterX = rect.midX
        let highlightOffset: CGFloat = isHighlighted ? 7 / zoomScale : 0
        let circleCenterY = diameter / 2 + highlightOffset
        let radius = diameter / 2

        // Tip of the pin (bottom point)
        let tipY = circleCenterY + radius + diameter * 0.45

        // The angle where the circle meets the tail (~40° from vertical axis)
        let tailAngle: CGFloat = .pi * 0.28

        // Tangent points on the circle where the tail begins
        let leftTX = circleCenterX - radius * sin(tailAngle)
        let leftTY = circleCenterY + radius * cos(tailAngle)
        let rightTX = circleCenterX + radius * sin(tailAngle)
        let rightTY = circleCenterY + radius * cos(tailAngle)

        // Highlight ring (pulsing glow behind the pin)
        if isHighlighted {
            let highlightPadding: CGFloat = 7 / zoomScale
            ctx.setFillColor(fillColor.withAlphaComponent(0.25).cgColor)
            ctx.addArc(
                center: CGPoint(x: circleCenterX, y: circleCenterY),
                radius: radius + highlightPadding,
                startAngle: 0, endAngle: .pi * 2, clockwise: false
            )
            ctx.fillPath()
        }

        // Shadow
        ctx.setShadow(
            offset: CGSize(width: 0, height: 2 / zoomScale),
            blur: 4 / zoomScale,
            color: UIColor.black.withAlphaComponent(0.45).cgColor
        )

        // Draw teardrop pin path
        let pinPath = UIBezierPath()

        // Start at the right tangent point
        pinPath.move(to: CGPoint(x: rightTX, y: rightTY))

        // Arc from right tangent, going counter-clockwise over the top, to left tangent
        // Start angle: measured from positive-x axis.
        let startAngle = CGFloat.pi / 2 - tailAngle
        let endAngle = CGFloat.pi / 2 + tailAngle
        pinPath.addArc(
            withCenter: CGPoint(x: circleCenterX, y: circleCenterY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        // Curve from left tangent to tip
        pinPath.addQuadCurve(
            to: CGPoint(x: circleCenterX, y: tipY),
            controlPoint: CGPoint(
                x: circleCenterX - radius * 0.20,
                y: leftTY + (tipY - leftTY) * 0.55
            )
        )

        // Curve from tip back to right tangent
        pinPath.addQuadCurve(
            to: CGPoint(x: rightTX, y: rightTY),
            controlPoint: CGPoint(
                x: circleCenterX + radius * 0.20,
                y: rightTY + (tipY - rightTY) * 0.55
            )
        )

        pinPath.close()

        // Fill the pin
        ctx.setFillColor(fillColor.cgColor)
        pinPath.fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // White border on the pin
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1.2 / zoomScale)
        pinPath.lineWidth = 1.2 / zoomScale
        pinPath.stroke()

        // Icon (centered in the circle head, not the tail)
        let iconPtSize = max(6, (diameter * zoomScale * 0.38) / zoomScale)
        let config = UIImage.SymbolConfiguration(pointSize: iconPtSize, weight: .bold)
        if let icon = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let iconSize = icon.size
            let iconOrigin = CGPoint(
                x: circleCenterX - iconSize.width / 2,
                y: circleCenterY - iconSize.height / 2
            )
            icon.draw(in: CGRect(origin: iconOrigin, size: iconSize))
        }

        // Label rendering (below the pin tip)
        if let label = label {
            let fontSize: CGFloat = 9 / zoomScale
            let paddingH: CGFloat = 5 / zoomScale
            let paddingV: CGFloat = 2 / zoomScale
            let gap: CGFloat = 4 / zoomScale

            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let nsLabel = label as NSString
            let maxLabelW = rect.width - paddingH * 2
            var labelSize = nsLabel.size(withAttributes: attrs)
            labelSize.width = min(labelSize.width, maxLabelW)

            let bgW = labelSize.width + paddingH * 2
            let bgH = labelSize.height + paddingV * 2
            let bgX = circleCenterX - bgW / 2
            let bgY = tipY + gap

            let bgRect = CGRect(x: bgX, y: bgY, width: bgW, height: bgH)
            let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: bgH / 2)

            ctx.setShadow(
                offset: CGSize(width: 0, height: 1 / zoomScale),
                blur: 2 / zoomScale,
                color: UIColor.black.withAlphaComponent(0.5).cgColor
            )
            UIColor.black.withAlphaComponent(0.55).setFill()
            bgPath.fill()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            let textRect = CGRect(
                x: bgRect.origin.x + paddingH,
                y: bgRect.origin.y + paddingV,
                width: labelSize.width,
                height: labelSize.height
            )
            nsLabel.draw(
                with: textRect,
                options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
        }
    }
}
