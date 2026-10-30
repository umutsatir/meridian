import CoreGraphics
import Foundation
import Observation

/// The chip playground of S03: a port of `initPos` / `step` of Onboarding.dc.html (own integrator,
/// no SpriteKit). Chips drift toward the centre, push each other apart and settle. The tray is 1088x430.
@Observable
final class ChipPhysics {
    struct Body {
        var x: Double, y: Double
        var w: Double, h: Double
        var rot: Double
    }

    static let trayWidth = 1088.0
    static let trayHeight = 430.0

    private(set) var bodies: [Body] = []
    private(set) var draggingIndex: Int?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var settleFrames = 0
    @ObservationIgnored private var dragOffset = CGSize.zero
    @ObservationIgnored private(set) var moved = false
    @ObservationIgnored private var dragStart = CGPoint.zero

    /// Chip size used by the physics (same formula as the canvas).
    static func size(forTitle title: String) -> (w: Double, h: Double) {
        (44 + (Double(title.count) * 8.4).rounded() + 14, 44)
    }

    /// Initial layout: seeded scatter (`rng(11)`) relaxed for 110 steps.
    func reset(titles: [String], staticGrid: Bool) {
        var r = OBRandom(seed: 11)
        let W = Self.trayWidth, H = Self.trayHeight
        var out: [Body] = []
        for t in titles {
            let s = Self.size(forTitle: t)
            let x = 60 + r.next() * (W - 120 - s.w)
            let y = 50 + r.next() * (H - 120)
            let rot = (r.next() - 0.5) * 12
            out.append(Body(x: x, y: y, w: s.w, h: s.h, rot: rot))
        }
        if staticGrid {
            bodies = Self.gridLayout(out)
            return
        }
        for _ in 0..<110 { Self.step(&out, dragIndex: nil) }
        bodies = out
    }

    /// Reduce Motion: rows of chips, centred, no rotation.
    static func gridLayout(_ input: [Body]) -> [Body] {
        var out = input
        let gap = 14.0, rowH = 44.0 + 16
        var rows: [[Int]] = [[]]
        var rowW = 0.0
        for (i, b) in out.enumerated() {
            if rowW + b.w > trayWidth - 120, !rows[rows.count - 1].isEmpty { rows.append([]); rowW = 0 }
            rows[rows.count - 1].append(i); rowW += b.w + gap
        }
        let totalH = Double(rows.count) * rowH - 16
        var y = (trayHeight - totalH) / 2
        for row in rows {
            let width = row.reduce(0.0) { $0 + out[$1].w } + Double(row.count - 1) * gap
            var x = (trayWidth - width) / 2
            for i in row { out[i].x = x; out[i].y = y; out[i].rot = 0; x += out[i].w + gap }
            y += rowH
        }
        return out
    }

    /// One relaxation step (`step(pos, W, H, dragIdx)`).
    static func step(_ pos: inout [Body], dragIndex: Int?) {
        let W = trayWidth, H = trayHeight
        let cx = W / 2, cy = H / 2 + 6
        for i in pos.indices where i != dragIndex {
            pos[i].x += (cx - (pos[i].x + pos[i].w / 2)) * 0.0016
            pos[i].y += (cy - (pos[i].y + pos[i].h / 2)) * 0.0022 + 0.12
        }
        for _ in 0..<3 {
            for i in 0..<pos.count {
                for j in (i + 1)..<max(pos.count, i + 1) {
                    let a = pos[i], b = pos[j]
                    let ox = min(a.x + a.w, b.x + b.w) - max(a.x, b.x) + 14
                    let oy = min(a.y + a.h, b.y + b.h) - max(a.y, b.y) + 14
                    guard ox > 0, oy > 0 else { continue }
                    var dx = 0.0, dy = 0.0
                    if ox < oy { dx = ox / 2 * ((a.x + a.w / 2) < (b.x + b.w / 2) ? -1 : 1) }
                    else { dy = oy / 2 * ((a.y + a.h / 2) < (b.y + b.h / 2) ? -1 : 1) }
                    if i != dragIndex { pos[i].x += dx; pos[i].y += dy }
                    if j != dragIndex { pos[j].x -= dx; pos[j].y -= dy }
                    if i == dragIndex { pos[j].x -= dx; pos[j].y -= dy }
                    if j == dragIndex { pos[i].x += dx; pos[i].y += dy }
                }
            }
        }
        for i in pos.indices {
            pos[i].x = max(10, min(W - 10 - pos[i].w, pos[i].x))
            pos[i].y = max(10, min(H - 10 - pos[i].h, pos[i].y))
        }
    }

    // MARK: Animation loop (90 frames after any interaction, like the canvas)

    func run() {
        settleFrames = 0
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                var b = self.bodies
                Self.step(&b, dragIndex: self.draggingIndex)
                self.bodies = b
                self.settleFrames += 1
                if self.settleFrames >= 90, self.draggingIndex == nil { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            self?.task = nil
        }
    }

    func stop() { task?.cancel(); task = nil }

    // MARK: Drag

    func beginDrag(_ i: Int, at p: CGPoint) {
        guard bodies.indices.contains(i) else { return }
        draggingIndex = i
        moved = false
        dragStart = p
        dragOffset = CGSize(width: p.x - bodies[i].x, height: p.y - bodies[i].y)
        run()
    }

    func drag(to p: CGPoint) {
        guard let i = draggingIndex else { return }
        if abs(p.x - dragStart.x) + abs(p.y - dragStart.y) > 4 { moved = true }
        bodies[i].x = p.x - dragOffset.width
        bodies[i].y = p.y - dragOffset.height
    }

    /// Returns the chip index when the gesture was a click (no movement).
    func endDrag() -> Int? {
        defer { draggingIndex = nil; run() }
        guard let i = draggingIndex, !moved else { return nil }
        return i
    }

    /// Adds room for a new chip at the top of the tray.
    func append(title: String) {
        let s = Self.size(forTitle: title)
        bodies.append(Body(x: (Self.trayWidth - s.w) / 2, y: 20, w: s.w, h: s.h, rot: 0))
        run()
    }
}
