import SwiftUI
import UIKit

// MARK: - VisitorMapView (UIScrollView wrapper — same approach as MapEditorView)

/// Uses the same UIScrollView-based rendering as the manager's InteractiveMapView
/// to guarantee pixel-perfect POI alignment. Markers scale dynamically with zoom,
/// trail paths are drawn in the image coordinate space, and the user location
/// indicator pulses correctly.
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

        let container = UIView()
        container.backgroundColor = .clear
        context.coordinator.containerView = container
        scrollView.addSubview(container)

        guard let img = UIImage(named: "astroni_map") else { return scrollView }
        let imageView = UIImageView(image: img)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        container.addSubview(imageView)
        context.coordinator.imageView = imageView

        DispatchQueue.main.async {
            context.coordinator.setupLayout(in: scrollView, image: img)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshMarkers(in: scrollView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: VisitorMapView
        weak var containerView: UIView?
        weak var imageView: UIImageView?
        private var userDotLayer: CALayer?
        private var pulseLayer: CALayer?

        init(_ parent: VisitorMapView) {
            self.parent = parent
        }

        func setupLayout(in scrollView: UIScrollView, image: UIImage) {
            guard let container = containerView,
                  let imageView = imageView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            let imgRatio = image.size.height / image.size.width

            let mapW = screenW
            let mapH = mapW * imgRatio

            imageView.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            container.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            scrollView.contentSize = CGSize(width: mapW, height: mapH)

            let scaleToFitH = screenH / mapH
            let initialScale = min(1.0, scaleToFitH)
            scrollView.minimumZoomScale = max(0.3, min(initialScale, 0.8))
            scrollView.zoomScale = initialScale

            let scaledH = mapH * initialScale
            let offsetY = max(0, scaledH - screenH)
            scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)

            refreshMarkers(in: scrollView)
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

            frameToCenter.origin.x = frameToCenter.size.width < boundsSize.width
                ? (boundsSize.width - frameToCenter.size.width) / 2 : 0
            frameToCenter.origin.y = frameToCenter.size.height < boundsSize.height
                ? (boundsSize.height - frameToCenter.size.height) / 2 : 0
            container.frame = frameToCenter
        }

        // MARK: - Refresh all markers & overlays

        func refreshMarkers(in scrollView: UIScrollView) {
            guard let container = containerView,
                  let imageView = imageView else { return }

            let imageSize = imageView.frame.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let currentScale = scrollView.zoomScale

            // Remove old overlays (but not the imageView)
            container.subviews
                .filter { $0 !== imageView }
                .forEach { $0.removeFromSuperview() }
            container.layer.sublayers?
                .filter { $0 !== imageView.layer && $0 !== container.layer }
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
            var points: [CGPoint] = [
                CGPoint(
                    x: parent.trail.startX * imageSize.width,
                    y: parent.trail.startY * imageSize.height
                )
            ]
            points += parent.trail.sortedSteps.compactMap { step in
                guard let poi = step.poi else { return nil }
                return CGPoint(x: poi.x * imageSize.width, y: poi.y * imageSize.height)
            }
            guard points.count >= 2 else { return }

            for i in 0..<(points.count - 1) {
                let segmentCompleted: Bool = {
                    if i == 0 {
                        return parent.trail.sortedSteps.first?.poi
                            .map { parent.completedPOIIds.contains($0.id) } ?? false
                    }
                    let fromPOI = parent.trail.sortedSteps[i - 1].poi
                    return fromPOI.map { parent.completedPOIIds.contains($0.id) } ?? false
                }()

                let pathLayer = CAShapeLayer()
                let path = UIBezierPath()
                path.move(to: points[i])
                path.addLine(to: points[i + 1])
                pathLayer.path = path.cgPath
                pathLayer.strokeColor = segmentCompleted
                    ? UIColor.gray.withAlphaComponent(0.45).cgColor
                    : UIColor(named: "WWFGreen")?.withAlphaComponent(0.75).cgColor
                        ?? UIColor.green.withAlphaComponent(0.75).cgColor
                pathLayer.lineWidth = 3
                pathLayer.fillColor = nil
                if !segmentCompleted {
                    pathLayer.lineDashPattern = [8, 4]
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
                label: nil  // No label on POI markers to keep clean
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

// MARK: - VisitorMarkerUIView (reusable marker drawn with CoreGraphics)

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

        // Label (if provided)
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
