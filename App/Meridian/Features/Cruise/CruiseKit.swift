import MeridianCore
import MeridianCruise
import MeridianMaps
import MeridianUI
import Observation
import SwiftUI

// MARK: - Data the screens draw

/// Everything the cruise screens need about a flight at one instant. Built from the live flight (`init(flight:)`) or
/// from numbers (the artboards: `p` = progress, 42 min LHR to CDG by default).
struct CruiseFrame: Equatable {
    var origin: Airport
    var destination: Airport?
    var progress: Double
    var totalMin: Double
    var remainingSec: Int
    var routeKm: Double
    var policy: PausePolicy = .normal
    var paused = false
    var held = false
    var mealHold = false
    /// Seconds of the flexible pause budget that are left.
    var pauseBudgetSec: Int = 600
    var flightNumber = "MR 0142"
    var gate = "A12"
    var isFree = false
    var elapsedSec = 0
    /// Local clock of the arrival, minutes since midnight (the canvas uses 10:42).
    var etaMinuteOfDay = 10 * 60 + 42
    /// The scene crossfade for the sun at the aircraft (live flights only).
    var windowBlend: WindowBlend?

    var distanceRemainingKm: Int { Int((routeKm * (1 - progress)).rounded()) }
    var flownMin: Int { max(1, Int((progress * totalMin).rounded())) }
    var flownKm: Int { Int((routeKm * progress).rounded()) }
    var isAmber: Bool { remainingSec <= 60 && progress > 0 && progress < 1 }

    /// Canvas phase boundaries (`B_` in `Flight.dc.html`) used by the dashboard footer and the readouts.
    var phaseName: String {
        let b: [Double] = [0, 0.01, 0.04, 0.07, 0.2, 0.84, 0.96, 1]
        let names = ["Boarding", "Taxi", "Take-off", "Climb", "Cruise", "Descent", "Landing"]
        var i = 0
        for k in 0..<7 where progress >= b[k] { i = k }
        return names[i]
    }

    /// `K.fmtKm`
    static func km(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","; f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }

    /// `remParts` of the canvas: h + min, min or sec.
    var remainingParts: [(value: String, unit: String)] {
        let s = remainingSec
        let m = Int((Double(s) / 60).rounded(.up))
        if s >= 3600 { return [(String(m / 60), "h"), (String(format: "%02d", m % 60), "min")] }
        if s > 60 { return [(String(m), "min")] }
        return [(String(s), "sec")]
    }

    /// `K.mmss`
    var remainingMMSS: String {
        let s = remainingSec
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    init(origin: Airport, destination: Airport?, progress: Double, totalMin: Double, policy: PausePolicy = .normal) {
        self.origin = origin
        self.destination = destination
        self.progress = progress
        self.totalMin = totalMin
        self.remainingSec = Int((totalMin * 60 * (1 - progress)).rounded())
        self.routeKm = destination.map { Geo.distanceKm(from: origin.coordinate, to: $0.coordinate) } ?? 0
        self.policy = policy
    }

    /// The artboard flight: `LHR` to `CDG`, 42 minutes, progress `p`.
    static func demo(p: Double, from: String = "LHR", to: String = "CDG", policy: PausePolicy = .normal) -> CruiseFrame {
        let idx = PlanKit.index
        let a = idx.airport(iata: from)!, b = idx.airport(iata: to)!
        var f = CruiseFrame(origin: a, destination: b, progress: p, totalMin: 42, policy: policy)
        f.pauseBudgetSec = 400
        return f
    }

    init?(flight: Flight, index: AirportIndex, now: Date) {
        guard let o = index.airport(iata: flight.originIata) else { return nil }
        let d = flight.destinationIata.flatMap { index.airport(iata: $0) }
        let total = (flight.durationSec ?? 0) / 60
        self.init(origin: o, destination: d, progress: flight.progress(at: now) ?? 0, totalMin: total, policy: flight.policy)
        remainingSec = Int((flight.remainingSec(at: now) ?? 0).rounded(.up))
        routeKm = flight.routeDistanceKm
        paused = flight.hold?.kind == .pause
        held = flight.isHeld
        mealHold = flight.hold?.kind == .meal
        isFree = flight.isFreeFlight
        elapsedSec = Int(flight.elapsedSec(at: now))
        let eta = Calendar.current.dateComponents([.hour, .minute], from: now.addingTimeInterval(TimeInterval(remainingSec)))
        etaMinuteOfDay = (eta.hour ?? 0) * 60 + (eta.minute ?? 0)
        pauseBudgetSec = Int(flight.pauseBudgetRemaining(at: now))
        windowBlend = CruiseSnapshot(flight: flight, origin: o, destination: d, now: now).window
    }
}

// MARK: - View state

enum CruiseView: String { case map, window, dash }

/// Local state of the cruise screens (`state` of `Flight.dc.html`). Artboards preset it, the live screen starts neutral.
@Observable
final class CruiseUI {
    var view: CruiseView = .map
    var style: MapStyle = .terra
    var route = true
    /// Follow camera (S16 "Follow plane"): following / free, north up / heading up, zoom.
    var camera = FollowCameraModel()
    var follow: Bool {
        get { camera.following }
        set { if newValue { camera.recenter() } else { camera.following = false } }
    }
    /// Written by the map layer every frame, read by the controls (not observed, so no extra redraws).
    @ObservationIgnored var lastCamera: FollowCamera?
    @ObservationIgnored var fitScale = 2.0
    @ObservationIgnored var engine: FollowCameraModel.Engine = .appleMaps
    /// The pointer is over the map controls: shows the orientation button.
    var controlsHover = false
    var zoomHover = false
    var menu: Menu?
    var scene = "day"
    /// Follow the sun at the aircraft (live) instead of the chosen scene.
    var sceneAuto = false
    var shade = 0.0
    var sound = true
    var capLabels = false
    var policySheet = false
    var holdProgress = 0.0
    var toastVisible = false
    var mealOpen = false

    enum Menu { case style, scene }

    init(view: CruiseView = .map, style: MapStyle = .terra) { self.view = view; self.style = style }

    /// `+` / `-` buttons and keys: one logarithmic step, about the plane (following) or the camera centre (free).
    func zoomStep(_ direction: Int) { camera.zoom(by: direction > 0 ? FollowCameraModel.step : 1 / FollowCameraModel.step, fit: fitScale, engine) }

    /// Wheel, pinch: about `anchor` (view coordinates) while free.
    func zoom(factor: Double, about anchor: CGPoint) {
        let target = camera.effectiveScale(fit: fitScale, engine) * factor
        camera.zoom(by: factor, fit: fitScale, engine)
        if let cam = lastCamera { camera.keepAnchor(anchor, camera: cam, newScale: FollowCameraModel.clamp(target, engine)) }
    }

    /// `F` / the Follow button: stop following, or recenter on the plane.
    func toggleFollow() { if let cam = lastCamera { camera.toggleFollow(camera: cam) } else { follow.toggle() } }

    /// Slider position 0...1 over the whole zoom range.
    var zoomK: Double {
        get { FollowCameraModel.k(forScale: camera.effectiveScale(fit: fitScale, engine), engine) }
        set { camera.setK(newValue, engine) }
    }
}

/// Real actions the screen can trigger. Artboards pass no-ops.
struct CruiseActions {
    var togglePause: () -> Void = {}
    var landEarly: () -> Void = {}
    var startBreak: () -> Void = {}
    var endBreak: () -> Void = {}
    var toggleSound: (Bool) -> Void = { _ in }
}

// MARK: - Shared drawing helpers

extension View {
    /// `.glass` plus the `.fl-amber` ring of the last minute.
    func cruiseGlass(_ radius: CGFloat, _ elevation: MRElevation = .e2, amber: Bool = false) -> some View {
        mrGlass(cornerRadius: radius, elevation: elevation)
            .overlay {
                if amber {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255, opacity: 0.55), lineWidth: 1.5)
                        .shadow(color: Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255, opacity: 0.22), radius: 22)
                        .allowsHitTesting(false)
                }
            }
    }

    func cruiseGlass<S: InsettableShape>(in shape: S, _ elevation: MRElevation = .e2, amber: Bool = false) -> some View {
        mrGlass(in: shape, elevation: elevation)
            .overlay {
                if amber {
                    shape.strokeBorder(Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255, opacity: 0.55), lineWidth: 1.5)
                        .shadow(color: Color(.sRGB, red: 1, green: 181 / 255, blue: 71 / 255, opacity: 0.22), radius: 22)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// CSS `radial-gradient(rx ry at cx cy, stops)` over a box (radii and centre in fractions of the box).
struct CSSEllipse: View {
    var cx = 0.5, cy = 0.5, rx: Double, ry: Double
    var stops: [Gradient.Stop]
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let pcx = cx * size.width, pcy = cy * size.height, prx = rx * size.width, pry = ry * size.height
            g.translateBy(x: pcx, y: pcy)
            g.scaleBy(x: prx, y: pry)
            let rect = CGRect(x: -pcx / prx, y: -pcy / pry, width: size.width / prx, height: size.height / pry)
            g.fill(Path(rect), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
        }
        .allowsHitTesting(false)
    }
}

func cruiseRGBA(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
    Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
}

/// `.tip`: tooltip bubble.
struct CruiseTip: View {
    let text: String
    var kbd: String?
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = MRPalette.resolve(scheme)
        HStack(spacing: 8) {
            Text(text).font(.mr(.ui, size: 12, weight: 500))
            if let kbd { MRKbd(kbd) }
        }
        .foregroundStyle(scheme == .dark ? p.text1.color : Color(RGB(hex: "#F3F5FA")))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(scheme == .dark ? cruiseRGBA(18, 26, 46, 0.92) : cruiseRGBA(20, 22, 28, 0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(p.strokeHair.color))
        .fixedSize()
        .shadow(color: p.e2.color.color, radius: p.e2.radius, x: p.e2.x, y: p.e2.y)
    }
}
