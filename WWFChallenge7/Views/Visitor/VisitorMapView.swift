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
        scrollView.contentInset = UIEdgeInsets(top: 40, left: 20, bottom: 320, right: 20)

        let container = UIView()
        container.backgroundColor = .clear
        context.coordinator.containerView = container
        scrollView.addSubview(container)

        // Setup the map pieces as requested
        let pieceNames = [
            "astroni_map_piece_1",
            "astroni_map_piece_2",
            "astroni_map_piece_3",
            "astroni_map_piece_4",
            "astroni_map_piece_5",
            "astroni_map_piece_6"
        ]
        
        var pieceImageViews: [UIImageView] = []
        var baseImage: UIImage? = nil
        
        for name in pieceNames {
            if let img = UIImage(named: name) {
                if baseImage == nil {
                    baseImage = img
                }
                let imageView = UIImageView(image: img)
                imageView.contentMode = .scaleAspectFit
                imageView.isUserInteractionEnabled = false
                container.addSubview(imageView)
                pieceImageViews.append(imageView)
            }
        }
        
        // Fallback to "astroni_map" if pieces are not yet loaded in Assets.xcassets
        if pieceImageViews.isEmpty, let fallbackImg = UIImage(named: "astroni_map") {
            baseImage = fallbackImg
            let imageView = UIImageView(image: fallbackImg)
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = false
            container.addSubview(imageView)
            pieceImageViews.append(imageView)
        }
        
        // Final fallback if absolutely nothing is loaded (creating dummy map sizing bounds)
        if baseImage == nil {
            baseImage = UIImage(systemName: "map")
        }
        
        context.coordinator.pieceImageViews = pieceImageViews

        if let imgToUse = baseImage {
            DispatchQueue.main.async {
                context.coordinator.setupLayout(in: scrollView, image: imgToUse)
            }
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshMarkers(in: scrollView)
        context.coordinator.animateToCurrentPosition(in: scrollView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: VisitorMapView
        weak var containerView: UIView?
        var pieceImageViews: [UIImageView] = []
        private var hasAnimatedEntrance = false
        var lastTargetPosition: CGPoint?
        private var userDotLayer: CALayer?
        private var pulseLayer: CALayer?

        init(_ parent: VisitorMapView) {
            self.parent = parent
        }

        func setupLayout(in scrollView: UIScrollView, image: UIImage) {
            guard let container = containerView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            let imageWidth = max(image.size.width, 1.0)
            let imgRatio = image.size.height / imageWidth

            let mapW = screenW
            let mapH = mapW * imgRatio

            container.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            
            // Set frame for all map pieces
            for pieceView in pieceImageViews {
                pieceView.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            }
            
            scrollView.contentSize = CGSize(width: mapW, height: mapH)

            let scaleToFitH = screenH / mapH
            let scaleToFitW = screenW / mapW
            let fitScale = min(scaleToFitH, scaleToFitW)
            
            scrollView.minimumZoomScale = max(0.3, fitScale)
            scrollView.maximumZoomScale = 6.0
            
            // Set a comfortable initial zoom (e.g. 2x the fit scale, capped at 3.0)
            let initialZoom = min(max(fitScale * 2.0, 1.5), 3.0)
            scrollView.zoomScale = initialZoom

            centerContent(in: scrollView)
            refreshMarkers(in: scrollView)
            animateToCurrentPosition(in: scrollView, force: true)
            
            // Beautiful piece animation!
            animatePiecesEntrance(screenHeight: screenH)
        }

        func animatePiecesEntrance(screenHeight: CGFloat) {
            guard !hasAnimatedEntrance else { return }
            hasAnimatedEntrance = true

            // Put all pieces up, transparent, scaled up and slightly rotated for a premium physical effect
            for pieceView in pieceImageViews {
                pieceView.transform = CGAffineTransform(translationX: 0, y: -screenHeight * 1.2)
                    .scaledBy(x: 1.15, y: 1.15)
                    .rotated(by: CGFloat.pi * -0.04) // Slight organic tilt
                pieceView.alpha = 0.0
            }

            // Animate each piece down sequentially
            for (index, pieceView) in pieceImageViews.enumerated() {
                let delay = Double(index) * 0.45 // Premium staggered delay
                
                UIView.animate(
                    withDuration: 1.4,
                    delay: delay,
                    usingSpringWithDamping: 0.72, // Physical soft spring bounce
                    initialSpringVelocity: 0.2,
                    options: [.curveEaseOut, .allowUserInteraction],
                    animations: {
                        pieceView.transform = .identity
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

            let bottomOverlayHeight: CGFloat = 300
            let visibleHeight = max(0, boundsSize.height - bottomOverlayHeight)

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            if frameToCenter.size.height < visibleHeight {
                frameToCenter.origin.y = (visibleHeight - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            container.frame = frameToCenter
        }

        func animateToCurrentPosition(in scrollView: UIScrollView, force: Bool = false) {
            let newPos = parent.currentNormalizedPosition
            if !force, let lastPos = lastTargetPosition, lastPos == newPos {
                return
            }
            lastTargetPosition = newPos
            
            guard let container = containerView else { return }
            
            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            let currentScale = scrollView.zoomScale
            
            let mapW = container.bounds.width / currentScale
            let mapH = container.bounds.height / currentScale
            
            let cx = newPos.x * mapW * currentScale
            let cy = newPos.y * mapH * currentScale
            
            let insets = scrollView.contentInset
            let minOffsetX = -insets.left
            let minOffsetY = -insets.top
            let maxOffsetX = max(minOffsetX, mapW * currentScale - screenW + insets.right)
            let maxOffsetY = max(minOffsetY, mapH * currentScale - screenH + insets.bottom)
            
            // Offset the vertical center to account for the bottom navigation panel
            let visibleCenterY = (screenH - 300) / 2
            
            let offsetX = max(minOffsetX, min(cx - screenW / 2, maxOffsetX))
            let offsetY = max(minOffsetY, min(cy - visibleCenterY, maxOffsetY))
            
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

            for step in sortedSteps {
                let isCompleted = parent.completedPOIIds.contains(step.poi?.id ?? UUID())
                let isNextActive = step.poi?.id == parent.currentStepPOIId
                
                // ONLY draw if pathGeometry exists. This forces admins to map trails.
                guard let geom = step.pathGeometry, !geom.isEmpty else { continue }
                
                let coords = PolylineCodec.decode(geom)
                let path = UIBezierPath()
                let points = coords.map { CGPoint(x: $0.latitude * imageSize.width, y: $0.longitude * imageSize.height) }
                
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
                    // Future steps: Very faint dotted line
                    pathLayer.strokeColor = UIColor(WWFDesign.Colors.forestLight).withAlphaComponent(0.15).cgColor
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
            let totalH = diameter + gap + labelH + (isAtStart ? 14 / zoomScale : 0)

            marker.frame = CGRect(
                x: cx - totalW / 2,
                y: cy - diameter / 2 - (isAtStart ? 7 / zoomScale : 0),
                width: totalW,
                height: totalH
            )

            container.addSubview(marker)
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
            let totalH = diameter + (isCurrent ? 16 / zoomScale : 0)

            marker.frame = CGRect(
                x: cx - totalW / 2,
                y: cy - diameter / 2 - (isCurrent ? 8 / zoomScale : 0),
                width: totalW,
                height: totalH
            )

            container.addSubview(marker)
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

// MARK: - VisitorMarkerUIView (Custom CoreGraphics rendering)

final class VisitorMarkerUIView: UIView {
    private let diameter: CGFloat
    private let fillColor: UIColor
    private let iconName: String
    private let zoomScale: CGFloat
    private let isHighlighted: Bool
    private let label: String?

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
        let circleCenterY = diameter / 2 + (isHighlighted ? 7 / zoomScale : 0)
        let radius = diameter / 2

        // Highlight ring
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
            color: UIColor.black.withAlphaComponent(0.4).cgColor
        )

        // Filled circle
        ctx.setFillColor(fillColor.cgColor)
        ctx.addArc(
            center: CGPoint(x: circleCenterX, y: circleCenterY),
            radius: radius,
            startAngle: 0, endAngle: .pi * 2, clockwise: false
        )
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // White border
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1 / zoomScale)
        ctx.addArc(
            center: CGPoint(x: circleCenterX, y: circleCenterY),
            radius: radius - 0.5 / zoomScale,
            startAngle: 0, endAngle: .pi * 2, clockwise: false
        )
        ctx.strokePath()

        // Icon
        let iconPtSize = max(6, (diameter * zoomScale * 0.35) / zoomScale)
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

        // Label rendering
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
            let bgY = circleCenterY + radius + gap

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
