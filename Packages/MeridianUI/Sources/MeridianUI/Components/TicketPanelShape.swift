import SwiftUI

/// One half of a boarding pass (main body or stub). The shared edge has half-circle notches
/// top and bottom. Below the tear front it is straight (still attached); above it follows the
/// seeded jagged line, so the main body and the stub interlock.
struct TicketPanelShape: Shape {
    enum Side { case main, stub }

    var side: Side
    var seed: UInt64
    /// 0...1, how far down the shared edge has been torn.
    var tearProgress: Double
    var cornerRadius: CGFloat = MRRadius.ticket
    var notchRadius: CGFloat = MRRadius.ticketNotch
    var amplitude: CGFloat = 3.5
    static let segments = 28

    var animatableData: Double {
        get { tearProgress }
        set { tearProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let offsets = TornEdge.offsets(seed: seed, count: Self.segments + 1)
        let edgeX = side == .main ? rect.maxX : rect.minX
        let edge: [CGPoint] = (0...Self.segments).map { i in
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(Self.segments)
            let torn = tearProgress > 0 && Double(i) / Double(Self.segments) <= tearProgress
            return CGPoint(x: edgeX + (torn ? CGFloat(offsets[i]) * amplitude : 0), y: y)
        }
        let r = min(cornerRadius, rect.height / 2)
        var p = Path()
        switch side {
        case .main:
            p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addLine(to: edge[0])
            edge.dropFirst().forEach { p.addLine(to: $0) }
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        case .stub:
            p.move(to: edge[0])
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
            p.addLine(to: edge[Self.segments])
            edge.dropLast().reversed().forEach { p.addLine(to: $0) }
        }
        p.closeSubpath()
        // Carve the half-circle notches where the two halves meet.
        var notches = Path()
        for y in [rect.minY, rect.maxY] {
            notches.addEllipse(in: CGRect(x: edgeX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        }
        return p.subtracting(notches)
    }
}
