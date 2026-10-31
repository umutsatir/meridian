import SwiftUI
import MeridianUI

/// Printer stage frames and tear poses, 520 x 720 each (same layout as the Ritual reference pages).
struct PaperPrintSheet: View {
    let times: [Double]
    var body: some View {
        PaperSheet {
            ForEach(Array(times.enumerated()), id: \.offset) { i, t in
                let frame = TicketPrintTimeline.frame(atMs: t, seed: PaperHash32.hash("LHRCDG"))
                TicketPrinterStage(model: .sample, frame: frame, stage: CGSize(width: 520, height: 720), centerX: 260, slotTop: 40)
                    .sheetAt(CGFloat(i) * 520, 0)
            }
        }
    }
}

enum PaperHash32 {
    static func hash(_ s: String) -> UInt32 { BoardingPassModel.designSeed(from: String(s.prefix(3)), to: String(s.suffix(3)), flight: "") }
}

struct PaperTearSheet: View {
    struct Pose { var p: Double; var grab: TearGrabSide }
    let poses: [Pose]
    var body: some View {
        PaperSheet {
            ForEach(Array(poses.enumerated()), id: \.offset) { i, pose in
                let ready = TicketPrintTimeline.frame(atMs: 2400, seed: PaperHash32.hash("LHRCDG"))
                ZStack(alignment: .topLeading) {
                    TicketPrinterStage(model: .sample, frame: ready, stage: CGSize(width: 520, height: 720), centerX: 260, slotTop: 40)
                    TearPreview(progress: pose.p, grab: pose.grab, rotation: ready.rotationDegrees)
                        .offset(x: 80, y: 60)
                }
                .sheetAt(CGFloat(i) * 520, 0)
            }
        }
    }
}

private struct TearPreview: View {
    @State private var tear = TicketTearModel()
    let progress: Double, grab: TearGrabSide, rotation: Double
    var body: some View {
        TearGesture(model: .sample, tear: tear)
            .rotationEffect(.degrees(rotation), anchor: UnitPoint(x: 0.5, y: 1))
            .onAppear { tear.preview(progress: progress, grab: grab) }
    }
}
