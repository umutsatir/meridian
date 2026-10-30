import MeridianCore
import MeridianMaps
import MeridianPlan
import SwiftUI

/// Geometry of the Plan map for a window size: the port of `model()` in `Planner.dc.html`
/// (zoom by duration, ring radius, projected airports and the greedy non-overlapping tag layout).
struct PlanScene {
    struct Tag: Identifiable {
        enum Kind { case selected, inRange, out }
        var id: String { airport.iata }
        let airport: Airport
        let kind: Kind
        let point: CGPoint
        let km: Double
        let minutes: Int
    }

    let size: CGSize
    let origin: Airport
    let zoom: Double
    let center: CGPoint          // screen position of the origin (cxW, cy)
    let ringRadius: Double
    let kmRadius: Double
    let tags: [Tag]
    let selected: Airport?
    let selectedPoint: CGPoint?
    let selectedKm: Double
    let arc: Path?

    /// `minutes`: ruler position (continuous while dragging). `nil` for a free flight (360 min ring).
    init(plan: PlanState, size: CGSize, minutes: Double?) {
        self.size = size
        let o = plan.origin
        origin = o
        let W = size.width, H = size.height
        let target = min(360, max(10, minutes ?? 360))
        let kmR = FlightTiming.km(forMinutes: target)
        kmRadius = kmR
        let z: Double = target <= 20 ? 2.6 : target <= 30 ? 1.8 : target <= 45 ? 1.25 : target <= 60 ? 0.95 : target <= 90 ? 0.7 : target <= 120 ? 0.56 : 0.45
        zoom = z
        let kmPerPx = 40075 * cos(o.coordinate.latitude * .pi / 180) / (EuropeProjection.k * 2 * .pi) / z
        ringRadius = max(24, kmR / kmPerPx)
        let cxW = W / 2, cy = (H * 0.34).rounded()
        center = CGPoint(x: cxW, y: cy)
        let oxy = EuropeProjection.xy(o.coordinate)
        let tx = cxW - oxy.x * z, ty = cy - oxy.y * z
        func scr(_ c: Coordinate) -> CGPoint {
            let q = EuropeProjection.xy(c)
            return CGPoint(x: q.x * z + tx, y: q.y * z + ty)
        }
        let allowMinor = PlanState.canvasMinorOrigins.contains(o.iata)
        struct Row { var a: Airport; var km: Double; var min: Int; var s: CGPoint }
        let all: [Row] = plan.index.airports.compactMap { a in
            guard a.iata != o.iata, allowMinor || !PlanState.canvasMinorAirports.contains(a.iata) else { return nil }
            let km = PlanKit.km(o, a)
            return Row(a: a, km: km, min: PlanState.canvasMinutes(forKm: km), s: scr(a.coordinate))
        }
        let cands = plan.destinations.compactMap { d in all.first { $0.a.iata == d.iata } }
        let sel = plan.selectedDestinationIata.flatMap { s in cands.first { $0.a.iata == s } }
        func inMap(_ r: Row) -> Bool { r.s.x > 40 && r.s.x < W - 40 && r.s.y > 76 && r.s.y < H * 0.6 }
        var placed: [CGPoint] = [], out: [Tag] = []
        func tryPlace(_ r: Row, _ kind: Tag.Kind) {
            guard inMap(r) else { return }
            if placed.contains(where: { abs($0.x - r.s.x) < 52 && abs($0.y - r.s.y) < 26 }) { return }
            placed.append(r.s)
            out.append(Tag(airport: r.a, kind: kind, point: r.s, km: r.km, minutes: r.min))
        }
        let inRange = all.filter { $0.km <= kmR + 1 }
        if let sel { tryPlace(sel, .selected) }
        for r in cands where out.count < 18 { tryPlace(r, .inRange) }
        for r in inRange where out.count < 22 && !cands.contains(where: { $0.a.iata == r.a.iata }) && r.km > 40 { tryPlace(r, .inRange) }
        for r in all.filter({ $0.km > kmR && $0.km < kmR * 1.28 }).sorted(by: { $0.km < $1.km }) where out.count < 26 { tryPlace(r, .out) }
        tags = out
        selected = sel?.a
        selectedPoint = sel?.s
        selectedKm = sel?.km ?? 0
        if let sel {
            // pathFrom(pts, scr, lift): the middle is raised by sin(f*pi)*lift px
            let lift = min(70, sel.km * 0.12 / kmPerPx)
            let pts = PlanKit.arc(o.coordinate, sel.a.coordinate)
            var path = Path()
            for (i, c) in pts.enumerated() {
                let f = Double(i) / Double(pts.count - 1)
                var p = scr(c)
                p.y -= sin(f * .pi) * lift
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            arc = path
        } else {
            arc = nil
        }
    }
}
