import MeridianUI
import SwiftUI

/// S37B: the eight story frames on the canvas' sheet (debug route only).
struct ExFramesSheet: View {
    private let caps = ["01 Cover", "02 Hours", "03 Distance", "04 Favourite scenario", "05 Longest flight", "06 Busiest day", "07 Every route", "08 Card reached"]
    var body: some View {
        let p = MRPalette.dark
        VStack(alignment: .leading, spacing: 40) {
            HStack(spacing: 10) {
                ExT(s: "S37", size: 12, weight: 600, lh: 12, color: p.text2.color, em: 0.08, upper: true)
                Rectangle().fill(p.strokeHair.color).frame(width: 24, height: 1)
                ExT(s: "Year in flight · the eight story frames (360 × 640, exported at 3×)", size: 12, weight: 600, lh: 12, color: p.text2.color, em: 0.08, upper: true)
            }
            HStack(alignment: .top, spacing: 24) {
                ForEach(0..<8, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 10) {
                        RecapFrame(index: i, data: .design)
                        ExT(s: caps[i], size: 11, weight: 600, lh: 14, color: p.text2.color, em: 0.06, upper: true)
                    }
                }
            }
            HStack(alignment: .top, spacing: 12) {
                ExT(s: "Native", size: 10, weight: 700, lh: 18, color: p.accent1.color, em: 0.12, upper: true)
                ExT(s: "Frames are SwiftUI views rendered with ImageRenderer at 3× (1080 × 1920) into a PNG that goes to ShareLink. Globes are MapKit snapshots; route glows are Core Image bloom. Numbers use New York Medium with tabular figures off for the display sizes.", fam: .mono, size: 12, weight: 400, lh: 18, color: p.text2.color, wrap: 840)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(p.fill1.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(p.strokeHair.color, lineWidth: 1))
            .frame(maxWidth: 900, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.top, 56).padding(.horizontal, 64).padding(.bottom, 72)
        .frame(width: 3320, height: 900, alignment: .topLeading)
        .background(p.bg0.color)
        .environment(\.colorScheme, .dark)
    }
}
