import AppKit
import Foundation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow
    case rectangle
    case highlight
    case pen

    var id: Self { self }

    var title: String {
        switch self {
        case .arrow:
            return "Arrow"
        case .rectangle:
            return "Box"
        case .highlight:
            return "Highlight"
        case .pen:
            return "Pen"
        }
    }

    var iconName: String {
        switch self {
        case .arrow:
            return "arrow.up.right"
        case .rectangle:
            return "rectangle"
        case .highlight:
            return "highlighter"
        case .pen:
            return "pencil.tip"
        }
    }
}

enum AnnotationColor: String, CaseIterable, Identifiable {
    case red
    case yellow
    case cyan
    case green

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }

    var color: NSColor {
        switch self {
        case .red:
            return NSColor(calibratedRed: 0.98, green: 0.24, blue: 0.24, alpha: 1)
        case .yellow:
            return NSColor(calibratedRed: 0.98, green: 0.79, blue: 0.18, alpha: 1)
        case .cyan:
            return NSColor(calibratedRed: 0.15, green: 0.75, blue: 0.95, alpha: 1)
        case .green:
            return NSColor(calibratedRed: 0.18, green: 0.82, blue: 0.45, alpha: 1)
        }
    }
}

struct NormalizedPoint: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
}

struct ImageAnnotation: Identifiable, Equatable, Sendable {
    let id = UUID()
    let tool: AnnotationTool
    let color: AnnotationColor
    var points: [NormalizedPoint]

    var isMeaningful: Bool {
        guard let firstPoint = points.first, let lastPoint = points.last else {
            return false
        }

        switch tool {
        case .pen:
            guard points.count > 1 else { return false }

            let totalDistance = zip(points, points.dropFirst()).reduce(CGFloat.zero) { partialResult, pair in
                partialResult + hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)
            }
            return totalDistance > 0.01
        case .arrow, .rectangle, .highlight:
            return hypot(firstPoint.x - lastPoint.x, firstPoint.y - lastPoint.y) > 0.01
        }
    }
}

enum AnnotationRenderer {
    static func draw(_ annotations: [ImageAnnotation], in imageRect: CGRect) {
        for annotation in annotations {
            draw(annotation, in: imageRect)
        }
    }

    private static func draw(_ annotation: ImageAnnotation, in imageRect: CGRect) {
        guard annotation.points.count >= 2 else { return }

        let lineWidth = max(4, min(imageRect.width, imageRect.height) * 0.008)
        let strokeColor = annotation.color.color

        switch annotation.tool {
        case .rectangle:
            let frame = rect(for: annotation, in: imageRect)
            let path = NSBezierPath(roundedRect: frame, xRadius: lineWidth * 1.2, yRadius: lineWidth * 1.2)
            path.lineWidth = lineWidth
            strokeColor.setStroke()
            path.stroke()
        case .highlight:
            let frame = rect(for: annotation, in: imageRect)
            let path = NSBezierPath(roundedRect: frame, xRadius: lineWidth, yRadius: lineWidth)
            strokeColor.withAlphaComponent(0.18).setFill()
            path.fill()
            path.lineWidth = max(2, lineWidth * 0.55)
            strokeColor.withAlphaComponent(0.9).setStroke()
            path.stroke()
        case .arrow:
            let startPoint = point(for: annotation.points[0], in: imageRect)
            let endPoint = point(for: annotation.points[annotation.points.count - 1], in: imageRect)
            drawArrow(from: startPoint, to: endPoint, color: strokeColor, lineWidth: lineWidth)
        case .pen:
            drawPen(annotation, in: imageRect, color: strokeColor, lineWidth: lineWidth)
        }
    }

    private static func drawPen(
        _ annotation: ImageAnnotation,
        in imageRect: CGRect,
        color: NSColor,
        lineWidth: CGFloat
    ) {
        guard let firstPoint = annotation.points.first else { return }

        let path = NSBezierPath()
        path.lineWidth = max(3, lineWidth * 0.9)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: point(for: firstPoint, in: imageRect))

        for pointValue in annotation.points.dropFirst() {
            path.line(to: point(for: pointValue, in: imageRect))
        }

        color.setStroke()
        path.stroke()
    }

    private static func drawArrow(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        color: NSColor,
        lineWidth: CGFloat
    ) {
        let shaft = NSBezierPath()
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.move(to: startPoint)
        shaft.line(to: endPoint)
        color.setStroke()
        shaft.stroke()

        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let headLength = max(12, lineWidth * 3.6)
        let headAngle = CGFloat.pi / 7
        let leftPoint = CGPoint(
            x: endPoint.x - cos(angle - headAngle) * headLength,
            y: endPoint.y - sin(angle - headAngle) * headLength
        )
        let rightPoint = CGPoint(
            x: endPoint.x - cos(angle + headAngle) * headLength,
            y: endPoint.y - sin(angle + headAngle) * headLength
        )

        let arrowHead = NSBezierPath()
        arrowHead.lineWidth = lineWidth
        arrowHead.lineCapStyle = .round
        arrowHead.move(to: endPoint)
        arrowHead.line(to: leftPoint)
        arrowHead.move(to: endPoint)
        arrowHead.line(to: rightPoint)
        color.setStroke()
        arrowHead.stroke()
    }

    private static func rect(for annotation: ImageAnnotation, in imageRect: CGRect) -> CGRect {
        let startPoint = point(for: annotation.points[0], in: imageRect)
        let endPoint = point(for: annotation.points[annotation.points.count - 1], in: imageRect)
        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(startPoint.x - endPoint.x),
            height: abs(startPoint.y - endPoint.y)
        )
    }

    private static func point(for normalizedPoint: NormalizedPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + normalizedPoint.x * imageRect.width,
            y: imageRect.minY + normalizedPoint.y * imageRect.height
        )
    }
}
