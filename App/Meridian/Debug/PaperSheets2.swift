import SwiftUI
import MeridianUI

struct PaperCardSheet: View {
    let variant: Int
    private func c(_ t: MembershipTier, _ x: CGFloat, _ y: CGFloat, locked: Bool = false, pose: CGPoint? = nil, flipped: Bool = false, size: MembershipCardSize = .list) -> some View {
        MembershipCardView(tier: t, size: size, locked: locked, pose: pose, flipped: .constant(flipped)).sheetAt(x, y)
    }
    var body: some View {
        PaperSheet {
            switch variant {
            case 1:
                ForEach(Array(MembershipTier.allCases.enumerated()), id: \.offset) { i, t in
                    c(t, 40 + CGFloat(i % 3) * 400, 40 + CGFloat(i / 3) * 254)
                }
            case 2:
                c(.gold, 40, 40, pose: CGPoint(x: -0.4, y: -0.3)); c(.gold, 440, 40, pose: CGPoint(x: 0.4, y: 0.3)); c(.gold, 840, 40, flipped: true)
                c(.obsidian, 40, 294, flipped: true); c(.gold, 440, 294, locked: true); c(.equator, 840, 294, locked: true)
            default:
                c(.jetstream, 40, 40, pose: CGPoint(x: 0.3, y: -0.2)); c(.cruise, 440, 40, pose: CGPoint(x: -0.2, y: 0.25)); c(.equator, 840, 40, pose: CGPoint(x: 0.35, y: 0.1))
                c(.departure, 40, 294, pose: CGPoint(x: -0.3, y: 0.3)); c(.obsidian, 440, 294, pose: CGPoint(x: 0.2, y: -0.3)); c(.gold, 840, 294, size: .hero)
            }
        }
    }
}

struct PaperStampSheet: View {
    var body: some View {
        PaperSheet(paperBackground: true) {
            let inks: [Color] = [PaperStampInk.blue, PaperStampInk.ok, PaperStampInk.red, PaperStampInk.warn]
            ForEach(Array(StampShape.allCases.enumerated()), id: \.offset) { i, s in
                StampView(shape: s, country: "FRANCE", code: "CDG", date: "29 OCT 2026", kind: "ARRIVAL", cc: "FR", ink: inks[i], rotation: -6, size: 200, seed: UInt32(3 + i))
                    .sheetAt(40 + CGFloat(i) * 300, 40)
                StampView(shape: s, country: "TURKIYE", code: "IST", date: "12 MAR 2026", kind: "DEPARTURE", cc: "TR", ink: inks[(i + 1) % 4], rotation: 5, size: 150, seed: UInt32(9 + i))
                    .sheetAt(40 + CGFloat(i) * 300, 280)
                StampView(shape: s, country: "JAPAN", code: "HND", date: "", kind: "ARRIVAL", cc: "JP", rotation: 0, size: 150, locked: true, seed: UInt32(1 + i))
                    .sheetAt(40 + CGFloat(i) * 300, 460)
            }
        }
    }
}

struct PaperFlapSheet: View {
    var body: some View {
        PaperSheet {
            let sizes: [(SplitFlapSize, CGFloat)] = [(.xs, 30), (.s, 80), (.m, 134), (.l, 204)]
            ForEach(Array(sizes.enumerated()), id: \.offset) { _, e in
                SplitFlapText("MR 0142 · A12", size: e.0, tone: .amber).sheetAt(30, e.1)
                SplitFlapText("LHR → CDG", size: e.0, tone: .white).sheetAt(640, e.1)
            }
            SplitFlapText("GATE B7", size: .m, tone: .amber, dim: true).sheetAt(30, 304)
        }
    }
}
