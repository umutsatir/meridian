import MeridianUI
import SwiftUI

/// DEBUG contact sheets for the card glare / foil / shimmer / frost work (`card-pose`, `card-lock`): fixed pointer poses and a
/// frozen shimmer phase (5 s of the 6 s loop), laid out like the canvas reference page used for comparison.
struct CardPoseSheet: View {
    let locked: Bool
    private struct Cell { var t: MembershipTier; var x: Double; var y: Double }
    private var cells: [Cell] {
        locked
        ? [.init(t: .gold, x: 0, y: 0), .init(t: .equator, x: 0, y: 0), .init(t: .obsidian, x: 0, y: 0),
           .init(t: .gold, x: -0.4, y: -0.3), .init(t: .equator, x: 0.3, y: -0.2), .init(t: .obsidian, x: 0.35, y: 0.3)]
        : [.init(t: .gold, x: 0, y: 0), .init(t: .jetstream, x: 0, y: 0), .init(t: .obsidian, x: 0, y: 0),
           .init(t: .gold, x: -0.4, y: -0.3), .init(t: .jetstream, x: 0.3, y: -0.2), .init(t: .obsidian, x: 0.35, y: 0.3),
           .init(t: .equator, x: 0.1, y: 0.1), .init(t: .departure, x: -0.3, y: 0.3), .init(t: .cruise, x: 0.4, y: -0.3)]
    }
    var body: some View {
        PaperSheet {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                let rest = c.x == 0 && c.y == 0
                MembershipCardView(tier: c.t, locked: locked, pose: rest ? nil : CGPoint(x: c.x, y: c.y), idlePhase: 5.0 / 6.0)
                    .sheetAt(40 + CGFloat(i % 3) * 400, 40 + CGFloat(i / 3) * 254)
            }
        }
    }
}
