import SwiftUI

/// Sprite metrics from icons.svg: 24x24 viewBox, 1.5 stroke, round caps and joins, `currentColor`.
public enum MRIconMetrics {
    public static let viewBox: CGFloat = 24
    public static let strokeWidth: CGFloat = 1.5
    /// CSS sizes: `svg.ic` 16, `.ic12`, `.ic14`, `.ic18`, `.ic20`, `.ic24`.
    public static let defaultSize: CGFloat = 16
}

/// One primitive of an icon, scaled from the 24-unit viewBox to the rect it is drawn in.
public struct MRIconShape: Shape {
    public let name: MRIconName
    public let filled: Bool

    public init(name: MRIconName, filled: Bool) { self.name = name; self.filled = filled }

    public func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / MRIconMetrics.viewBox
        let t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: k, y: k)
        return MRIconCache.path(name, filled: filled).applying(t)
    }
}

/// An icon from the canvas sprite. Color comes from `foregroundStyle` (the sprite's `currentColor`).
/// Stroke width scales with `size` exactly as the SVG does (1.5 of 24).
public struct MRIcon: View {
    private let name: MRIconName
    private let size: CGFloat

    public init(_ name: MRIconName, size: CGFloat = MRIconMetrics.defaultSize) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let hasStroke = (MRIconData.parts[name] ?? []).contains { !$0.filled }
        let hasFill = (MRIconData.parts[name] ?? []).contains { $0.filled }
        ZStack {
            if hasStroke {
                MRIconShape(name: name, filled: false)
                    .stroke(style: StrokeStyle(lineWidth: MRIconMetrics.strokeWidth * size / MRIconMetrics.viewBox, lineCap: .round, lineJoin: .round))
            }
            if hasFill {
                MRIconShape(name: name, filled: true).fill(style: FillStyle(eoFill: false))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Parsed icon paths in viewBox units, built once per icon.
enum MRIconCache {
    private nonisolated(unsafe) static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    static func path(_ name: MRIconName, filled: Bool) -> Path {
        let key = "\(name.rawValue)|\(filled)"
        lock.lock(); defer { lock.unlock() }
        if let p = cache[key] { return p }
        var p = Path()
        for part in MRIconData.parts[name] ?? [] where part.filled == filled { p.addPath(SVGPath.parse(part.d)) }
        cache[key] = p
        return p
    }
}
