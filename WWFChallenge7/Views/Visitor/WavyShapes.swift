import SwiftUI

// MARK: - Top Header Blob
struct TopWavyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Linea superiore arriva fino all'80% dello schermo (prima del tasto 3D)
        path.addLine(to: CGPoint(x: w * 0.80, y: 0))
        
        // Scende passando ESATTAMENTE tra il testo (che finisce al 72%) e il tasto 3D (che inizia all'82%)
        path.addCurve(to: CGPoint(x: w * 0.76, y: h * 0.55),
                      control1: CGPoint(x: w * 0.80, y: h * 0.2),
                      control2: CGPoint(x: w * 0.78, y: h * 0.4))
                      
        // Rientra in diagonale per creare l'effetto "schizzo di pittura" bello profondo
        path.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.80),
                      control1: CGPoint(x: w * 0.74, y: h * 0.7),
                      control2: CGPoint(x: w * 0.65, y: h * 0.80))
                      
        // Pancia morbida verso il basso
        path.addCurve(to: CGPoint(x: w * 0.25, y: h * 0.95),
                      control1: CGPoint(x: w * 0.45, y: h * 0.80),
                      control2: CGPoint(x: w * 0.35, y: h * 0.95))
                      
        // Chiusura fluida verso sinistra
        path.addCurve(to: CGPoint(x: 0, y: h * 0.60),
                      control1: CGPoint(x: w * 0.1, y: h * 0.95),
                      control2: CGPoint(x: 0, y: h * 0.75))
                      
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Bottom Tab Bar Shape
struct BottomWavyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Valli più alte per non finire sotto i bottoni
        let edgeY = h * 0.45
        let valleyY = h * 0.35
        let peakOuterY = h * 0.10 // Esplora e Profilo più alti
        let peakInnerY = h * 0.20 // Eventi più basso
        
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: edgeY))
        
        // Salita fluida verso Peak 1
        path.addCurve(to: CGPoint(x: w * 0.18, y: peakOuterY),
                      control1: CGPoint(x: w * 0.05, y: edgeY),
                      control2: CGPoint(x: w * 0.1, y: peakOuterY))
                      
        // Discesa morbida verso Valley 1
        path.addCurve(to: CGPoint(x: w * 0.35, y: valleyY),
                      control1: CGPoint(x: w * 0.25, y: peakOuterY),
                      control2: CGPoint(x: w * 0.3, y: valleyY))
                      
        // Salita al Peak 2 (centrale, più basso)
        path.addCurve(to: CGPoint(x: w * 0.50, y: peakInnerY),
                      control1: CGPoint(x: w * 0.4, y: valleyY),
                      control2: CGPoint(x: w * 0.45, y: peakInnerY))
                      
        // Discesa morbida verso Valley 2
        path.addCurve(to: CGPoint(x: w * 0.65, y: valleyY),
                      control1: CGPoint(x: w * 0.55, y: peakInnerY),
                      control2: CGPoint(x: w * 0.6, y: valleyY))
                      
        // Salita fluida verso Peak 3
        path.addCurve(to: CGPoint(x: w * 0.82, y: peakOuterY),
                      control1: CGPoint(x: w * 0.7, y: valleyY),
                      control2: CGPoint(x: w * 0.75, y: peakOuterY))
                      
        // Discesa al margine destro
        path.addCurve(to: CGPoint(x: w, y: edgeY),
                      control1: CGPoint(x: w * 0.9, y: peakOuterY),
                      control2: CGPoint(x: w * 0.95, y: edgeY))
                      
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Card Blob Background
struct CardBlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Straight left edge (touches card corner)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w * 0.6, y: 0))
        
        // Wavy right edge from top to bottom
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.5),
                          control: CGPoint(x: w * 1.2, y: h * 0.25))
                          
        path.addQuadCurve(to: CGPoint(x: w * 0.7, y: h),
                          control: CGPoint(x: -w * 0.2, y: h * 0.75))
                          
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Teardrop Pin Shape
struct TeardropPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        teardropPath(in: rect)
    }

    static func cgPath(in rect: CGRect) -> CGPath {
        let path = TeardropPinShape().teardropPath(in: rect)
        return path.cgPath
    }

    private func teardropPath(in rect: CGRect) -> Path {
        var path = Path()

        let circleRadius = rect.width / 2
        let circleCenterY = circleRadius
        let circleCenterX = rect.midX
        let tipY = rect.maxY

        let angle: CGFloat = .pi * 0.28

        let leftTangentY = circleCenterY + circleRadius * cos(angle)
        let rightTangentX = circleCenterX + circleRadius * sin(angle)
        let rightTangentY = circleCenterY + circleRadius * cos(angle)

        path.move(to: CGPoint(x: rightTangentX, y: rightTangentY))
        path.addArc(
            center: CGPoint(x: circleCenterX, y: circleCenterY),
            radius: circleRadius,
            startAngle: .radians(.pi / 2 - Double(angle)),
            endAngle: .radians(.pi / 2 + Double(angle)),
            clockwise: true
        )

        path.addQuadCurve(
            to: CGPoint(x: circleCenterX, y: tipY),
            control: CGPoint(x: circleCenterX - circleRadius * 0.22, y: leftTangentY + (tipY - leftTangentY) * 0.55)
        )

        path.addQuadCurve(
            to: CGPoint(x: rightTangentX, y: rightTangentY),
            control: CGPoint(x: circleCenterX + circleRadius * 0.22, y: rightTangentY + (tipY - rightTangentY) * 0.55)
        )

        path.closeSubpath()
        
        // Rotate the path by 35 degrees clockwise around the center of the circular head
        let center = CGPoint(x: circleCenterX, y: circleCenterY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: 35 * .pi / 180)
            .translatedBy(x: -center.x, y: -center.y)
            
        return path.applying(transform)
    }
}
