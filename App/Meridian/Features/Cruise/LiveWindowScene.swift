import AppKit
import MeridianCore
import MeridianCruise
import MeridianMaps
import Observation
import SwiftUI

// MARK: - Weather (Open-Meteo), one shared instance

/// Real weather along the current route (Open-Meteo, 10 minute cache). No network: sun and no clouds.
@MainActor @Observable
final class LiveWeather {
    static let shared = LiveWeather()

    private(set) var profile: WeatherProfile = .clear
    @ObservationIgnored private var key: String?
    @ObservationIgnored private var loadedAt = Date.distantPast
    @ObservationIgnored private var loading = false
    @ObservationIgnored private let service = WeatherService()

    /// Idempotent: fetches when the route changed or the data is older than the cache time.
    func ensure(from a: Coordinate, to b: Coordinate) {
        let k = String(format: "%.2f,%.2f>%.2f,%.2f", a.latitude, a.longitude, b.latitude, b.longitude)
        let fresh = Date().timeIntervalSince(loadedAt) < WeatherService.ttl
        guard !loading, k != key || !fresh else { return }
        loading = true
        key = k
        Task {
            let p = await service.profile(from: a, to: b)
            profile = p
            loadedAt = p.isFallback ? Date().addingTimeInterval(-WeatherService.ttl + 60) : Date()   // retry a failed fetch after a minute
            loading = false
        }
    }
}

// MARK: - Fixed conditions for screenshots

/// A frozen aircraft position and time (`--at lat,lon,ISO8601`, `--heading`, `--alt`, `--weather cover,precip,code`).
struct WindowFixture {
    var position: Coordinate
    var heading: Double
    var date: Date
    var altitudeFt: Double
    var weather: WeatherCondition?

    @MainActor static var active: WindowFixture?

    static func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s) ?? Date() }

    /// Defaults of a route, overridden by the launch arguments.
    static func make(lat: Double, lon: Double, at: String, heading: Double = 90, altitudeFt: Double = 30_000, weather: WeatherCondition? = nil) -> WindowFixture {
        let a = CommandLine.arguments
        func value(_ f: String) -> String? { a.firstIndex(of: f).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } }
        var fx = WindowFixture(position: .init(latitude: lat, longitude: lon), heading: heading, date: iso(at), altitudeFt: altitudeFt, weather: weather)
        if let s = value("--at") {
            let p = s.split(separator: ",", maxSplits: 2).map(String.init)
            if p.count == 3, let la = Double(p[0]), let lo = Double(p[1]) { fx.position = .init(latitude: la, longitude: lo); fx.date = iso(p[2]) }
        }
        if let h = value("--heading").flatMap(Double.init) { fx.heading = h }
        if let h = value("--alt").flatMap(Double.init) { fx.altitudeFt = h }
        if let w = value("--weather")?.split(separator: ",").compactMap({ Double($0) }), w.count == 3 {
            fx.weather = WeatherCondition(cloudCover: w[0], precipitationMM: w[1], weatherCode: Int(w[2]), windKmh: 12)
        }
        return fx
    }
}

// MARK: - What the window shows

/// Everything the scene needs: sun, atmosphere and altitude. Resolved from the real sun and weather (auto) or from a chosen scene.
struct WindowLook: Equatable {
    var sunElevation: Double
    var sunAzimuth: Double
    var atmosphere: WindowAtmosphere
    var altitudeFt: Double
    var runway = false
    var position: Coordinate
    var heading: Double
    var side: WindowSide = .left
    /// The aircraft along its route over time; `nil` freezes the view (fixtures, artboards).
    var motion: WindowMotion?
    var cruiseFt = 30_000.0
    /// A fixed altitude (fixture, take-off / landing scenes) instead of the phase profile.
    var altitudeOverrideFt: Double?

    var grade: DayNightGrade { .weights(elevation: sunElevation) }
    /// MapKit limits the pitch to 35 degrees; the extra tilt comes from `tilt`.
    var camera: WindowCameraSpec {
        WindowCamera.spec(position: position, heading: heading, side: side, altitudeFt: altitudeFt, pitch: 35)
    }
    var tilt: Double {
        let a = CommandLine.arguments
        let dbg = a.firstIndex(of: "--tilt").flatMap { $0 + 1 < a.count ? Double(a[$0 + 1]) : nil }
        return dbg ?? WindowCamera.tiltDegrees(altitudeFt: altitudeFt)
    }

    /// The look at `date`: position, heading and altitude follow the motion (the sun and weather stay those of the last update).
    func at(_ date: Date) -> WindowLook {
        guard let m = motion else { return self }
        var l = self
        let p = m.progress(at: date)
        let s = m.state(progress: p)
        l.position = s.position
        l.heading = s.heading
        if altitudeOverrideFt == nil { l.altitudeFt = WindowCamera.altitudeFt(progress: p, cruiseFt: cruiseFt) }
        return l
    }

    /// The real sun and weather at `position` and `date`.
    static func real(position: Coordinate, heading: Double, date: Date, progress: Double, routeKm: Double, weather: WeatherCondition,
                     altitudeFt: Double? = nil, side: WindowSide = .left) -> WindowLook {
        let sun = SunElevation.position(at: date, coordinate: position)
        let cruise = WindowCamera.cruiseAltitudeFt(routeKm: routeKm)
        let alt = altitudeFt ?? WindowCamera.altitudeFt(progress: progress, cruiseFt: cruise)
        var l = WindowLook(sunElevation: sun.elevation, sunAzimuth: sun.azimuth, atmosphere: WindowAtmosphere(weather), altitudeFt: alt,
                           runway: progress > 0.96, position: position, heading: heading, side: side)
        l.cruiseFt = cruise
        l.altitudeOverrideFt = altitudeFt
        return l
    }

    /// A chosen scene of the menu: fixed sun and weather, the real position and phase altitude.
    static func manual(_ key: String, position: Coordinate, heading: Double, progress: Double, routeKm: Double, side: WindowSide = .left) -> WindowLook {
        let alt = WindowCamera.altitudeFt(progress: progress, cruiseFt: WindowCamera.cruiseAltitudeFt(routeKm: routeKm))
        var l = WindowLook(sunElevation: 45, sunAzimuth: heading + side.headingOffset + 25, atmosphere: WindowAtmosphere(cloud: 0.3), altitudeFt: alt,
                           position: position, heading: heading, side: side)
        let rel = heading + side.headingOffset
        switch key {
        case "sunset": l.sunElevation = 1.5; l.sunAzimuth = rel - 22; l.atmosphere = .init(cloud: 0.35)
        case "blue": l.sunElevation = -5; l.sunAzimuth = rel - 30; l.atmosphere = .init(cloud: 0.25)
        case "night": l.sunElevation = -30; l.atmosphere = .clear
        case "rain": l.sunElevation = 30; l.atmosphere = .init(cloud: 0.92, rain: 0.6)
        case "storm": l.sunElevation = 14; l.atmosphere = .init(cloud: 1, rain: 1, storm: true)
        case "takeoff": l.altitudeFt = 1_200; l.altitudeOverrideFt = 1_200
        case "landing": l.altitudeFt = 1_000; l.altitudeOverrideFt = 1_000; l.sunElevation = 8; l.sunAzimuth = rel - 26; l.runway = true
        default: break
        }
        l.cruiseFt = WindowCamera.cruiseAltitudeFt(routeKm: routeKm)
        return l
    }
}

extension CruiseFrame {
    /// Aircraft position and heading along the route (great circle).
    var windowPosition: (Coordinate, Double) {
        let o = origin.coordinate, d = (destination ?? origin).coordinate
        let pos = Geo.interpolate(from: o, to: d, fraction: progress)
        let ahead = Geo.distanceKm(from: pos, to: d) > 0.5
        return (pos, ahead ? Geo.bearing(from: pos, to: d) : Geo.bearing(from: o, to: d))
    }

    func windowLook(ui: CruiseUI) -> WindowLook {
        let (pos, hdg) = windowPosition
        let fx = ui.sceneAuto ? WindowFixture.active : nil
        // the aircraft keeps flying between two frames (live flights); artboards and fixtures are frozen
        var motion: WindowMotion?
        if fx == nil, let d = date, !held, !paused, totalMin > 0 {
            motion = WindowMotion(origin: origin.coordinate, destination: (destination ?? origin).coordinate, progress: progress,
                                  ratePerSec: 1 / (totalMin * 60), anchor: d)
        }
        var look: WindowLook
        if ui.sceneAuto {
            let p = fx?.position ?? pos
            let w = fx?.weather ?? LiveWeather.shared.profile.condition(at: progress)
            look = .real(position: p, heading: fx?.heading ?? hdg, date: fx?.date ?? date ?? .now, progress: progress, routeKm: routeKm,
                         weather: w, altitudeFt: fx?.altitudeFt, side: ui.windowSide)
        } else {
            look = .manual(ui.scene, position: pos, heading: hdg, progress: progress, routeKm: routeKm, side: ui.windowSide)
        }
        look.motion = motion
        return look
    }
}

// MARK: - Scene

/// The window content without the cabin: satellite ground, real clouds, grade, lights, haze, sun, procedural clouds, fog, rain.
struct LiveWindowScene: View {
    let look: WindowLook
    let size: CGSize
    var animated = true
    @State private var mapFailed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the far edge of the tilted ground sits, as a fraction of the scene height (upper third at cruise).
    static let horizon = 0.27
    static let mapDrop = 0.275

    static let cloudDay: Date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: .now) ?? .now

    var body: some View {
        let g = look.grade
        let a = look.atmosphere
        let top = g.skyTop, hor = g.skyHorizon
        // overcast greys the sky
        let grey = a.cloud * 0.65 * (g.day + g.golden * 0.6)
        let hz = Self.horizon
        ZStack(alignment: .topLeading) {
            // sky above the horizon
            LinearGradient(stops: [.init(color: skyC(top, grey), location: 0), .init(color: skyC(hor, grey), location: hz)], startPoint: .top, endPoint: .bottom)

            // the ground: satellite imagery tilted towards the horizon, following the aircraft frame by frame
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30, paused: look.motion == nil && reduceMotion)) { tl in
                let now = tl.date
                let l = look.at(now)
                let t = now.timeIntervalSinceReferenceDate
                // slight head sway behind the glass (the wall of the window has depth); off with Reduce Motion
                let sx = reduceMotion ? 0 : sin(t * 0.43) * 2.4 + sin(t * 0.17) * 1.6
                let sy = reduceMotion ? 0 : sin(t * 0.31 + 1) * 1.2
                LiveWindowMap(camera: l.camera, tint: g.groundTint, lights: g.lights, cloudAlpha: 0.18 + 0.75 * a.cloud,
                              cloudDay: Self.cloudDay, animated: false, onHealth: { mapFailed = $0 })
                    .frame(width: size.width * 1.7, height: size.height * 1.7)
                    .rotation3DEffect(.degrees(l.tilt), axis: (1, 0, 0), anchor: .bottom, perspective: 0.45)
                    .offset(x: sx, y: size.height * Self.mapDrop + sy)
                    .frame(width: size.width, height: size.height, alignment: .bottom)
            }

            // horizon: haze band over the far edge of the ground, fading downwards
            LinearGradient(stops: [.init(color: skyC(hor, grey, 0), location: hz - 0.10), .init(color: skyC(hor, grey, 1.0), location: hz + 0.005),
                                   .init(color: skyC(hor, grey, 0.80 + 0.15 * a.cloud), location: hz + 0.035),
                                   .init(color: skyC(hor, grey, 0.30), location: hz + 0.14), .init(color: skyC(hor, grey, 0), location: hz + 0.34)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            // overcast: the light is flat and the ground dimmer
            if a.cloud > 0.3 {
                Rectangle().fill(cruiseRGBA(74, 82, 96, 0.30 * (a.cloud - 0.3) / 0.7 * (g.day + g.golden * 0.5))).allowsHitTesting(false)
            }

            // low sun: warm glow towards the sun's azimuth
            sunGlow(g)

            // procedural clouds from the weather's cloud cover (parallax, slow drift)
            if a.cloud > 0.08 { ProceduralClouds(cover: a.cloud, grade: g, drift: !reduceMotion).frame(width: size.width, height: size.height) }

            if a.fog > 0.02 {
                Rectangle().fill(LinearGradient(colors: [fogColor(g, 0.9 * a.fog), fogColor(g, 0.55 * a.fog)], startPoint: .top, endPoint: .bottom)).allowsHitTesting(false)
            }
            if a.rain > 0.02 { WindowRain(storm: a.storm, intensity: a.rain).frame(width: size.width, height: size.height) }
            if look.runway { RunwayLights().frame(width: size.width, height: size.height) }
            // the wing of a window seat: part of the aircraft, it does not move with the world
            WingView(side: look.side, grade: g, cloud: a.cloud)
                .frame(width: min(size.width, size.height * 0.85), height: size.height)
                .frame(width: size.width, height: size.height, alignment: look.side == .left ? .trailing : .leading)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay { if mapFailed || MapHealth.shared.failed { PhotoFallback(look: look).frame(width: size.width, height: size.height) } }
    }

    private func skyC(_ c: DayNightGrade.RGBA, _ grey: Double, _ o: Double = 1) -> Color {
        cruiseRGBA(c.r + (176 - c.r) * grey, c.g + (182 - c.g) * grey, c.b + (190 - c.b) * grey, o)
    }

    private func fogColor(_ g: DayNightGrade, _ o: Double) -> Color {
        let day = (206.0, 212.0, 218.0), night = (18.0, 22.0, 34.0), warm = (232.0, 196.0, 170.0), blue = (96.0, 106.0, 150.0)
        let r = g.day * day.0 + g.night * night.0 + g.golden * warm.0 + g.blue * blue.0
        let gg = g.day * day.1 + g.night * night.1 + g.golden * warm.1 + g.blue * blue.1
        let b = g.day * day.2 + g.night * night.2 + g.golden * warm.2 + g.blue * blue.2
        return cruiseRGBA(r, gg, b, o)
    }

    @ViewBuilder private func sunGlow(_ g: DayNightGrade) -> some View {
        let rel = SunGlare.relativeAzimuth(sun: look.sunAzimuth, viewHeading: look.camera.heading)
        let strength = (g.glow * 0.8 + g.day * 0.16) * (1 - look.atmosphere.cloud * 0.7) * (look.sunElevation > -4 ? 1 : 0)
        if abs(rel) < 75, strength > 0.01 {
            let x = 0.5 + rel / 80
            let y = max(0.04, Self.horizon - max(0, look.sunElevation) / 90 * 0.22)
            CSSEllipse(cx: x, cy: y, rx: 0.55, ry: 0.5, stops: [
                .init(color: cruiseRGBA(255, 238, 200, 0.75 * strength), location: 0),
                .init(color: cruiseRGBA(255, 170, 100, 0.34 * strength), location: 0.22),
                .init(color: cruiseRGBA(255, 130, 80, 0), location: 0.75)])
                .blendMode(.screen)
        }
    }
}

/// Soft cloud layers on the glass side of the scene (`wv-cloud-a/b`), tinted by the light, drifting slowly with different speeds.
private struct ProceduralClouds: View {
    let cover: Double
    let grade: DayNightGrade
    let drift: Bool

    private static func image(_ n: String) -> NSImage? { Bundle.main.url(forResource: n, withExtension: "png").flatMap { NSImage(contentsOf: $0) } }

    var body: some View {
        // cloud colour: white by day, warm at golden hour, bluish at blue hour, dark at night
        let tint = cruiseRGBA(255 * grade.day + 255 * grade.golden + 150 * grade.blue + 38 * grade.night,
                              255 * grade.day + 205 * grade.golden + 160 * grade.blue + 44 * grade.night,
                              255 * grade.day + 170 * grade.golden + 215 * grade.blue + 70 * grade.night)
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !drift)) { tl in
                let t = drift ? tl.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    layer("wv-cloud-a", geo.size, scale: 1.9, speed: 3.0, t: t, opacity: min(0.7, pow(cover, 1.6) * 0.55), y: 0.1)
                    layer("wv-cloud-b", geo.size, scale: 1.2, speed: 6.5, t: t, opacity: min(0.45, pow(cover, 2.0) * 0.4), y: 0.45)
                }
                .colorMultiply(tint)
                .mask(LinearGradient(stops: [.init(color: .black.opacity(0.35), location: 0), .init(color: .black, location: 0.35), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func layer(_ name: String, _ size: CGSize, scale: Double, speed: Double, t: Double, opacity: Double, y: Double) -> some View {
        if let img = Self.image(name) {
            let w = size.width * scale
            let h = w
            let dx = (t * speed).truncatingRemainder(dividingBy: w)
            Canvas { ctx, sz in
                let res = ctx.resolve(Image(nsImage: img))
                var x = -dx - w
                while x < sz.width {
                    var yy = sz.height * y - h * 0.5
                    while yy < sz.height { ctx.draw(res, in: CGRect(x: x, y: yy, width: w, height: h)); yy += h }
                    x += w
                }
            }
            .opacity(opacity)
            .blur(radius: 1.2)
        }
    }
}

/// Bundled photos: only used when the map or the network is not available.
private struct PhotoFallback: View {
    let look: WindowLook
    var body: some View {
        let g = look.grade
        let key = g.night > 0.5 ? "night" : g.blue > 0.5 ? "blue" : g.golden > 0.5 ? "sunset" : look.atmosphere.raining ? "rain" : "day"
        let s = WindowSceneSpec.spec(key)
        GeometryReader { geo in
            if let img = WindowPhoto.image(s.image) {
                let scale = max(geo.size.width / img.size.width, geo.size.height / img.size.height)
                Image(nsImage: img).resizable().interpolation(.high)
                    .frame(width: img.size.width * scale, height: img.size.height * scale)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            } else {
                Color(nsColor: .black)
            }
        }
    }
}

// MARK: - Wing

/// The wing seen from a window seat: a swept, slightly tapered surface rising from the bottom edge towards the horizon, with
/// flap seams, a bright leading edge, a navigation light and a strobe at night. Lit by the same grade as the world.
struct WingView: View {
    let side: WindowSide
    let grade: DayNightGrade
    let cloud: Double

    var body: some View {
        // brightness of the metal: full by day, warm at golden hour, dim at dusk, nearly dark at night
        let lit = grade.day * 1 + grade.golden * 0.82 + grade.blue * 0.42 + grade.night * 0.16
        let warm = grade.golden * 0.5
        let sky = (1 - cloud * 0.25)
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let mirror = side == .right
                func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: (mirror ? 1 - x : x) * w, y: y * h) }
                func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
                    Color(.sRGB, red: min(255, (r + 30 * warm) * lit * sky) / 255, green: min(255, (g + 10 * warm) * lit * sky) / 255, blue: min(255, (b - 20 * warm) * lit * sky) / 255, opacity: a)
                }
                // outline: leading edge from the root (bottom right) to the tip (upper left), trailing edge back
                var wing = Path()
                wing.move(to: p(1.08, 1.04))
                wing.addCurve(to: p(0.16, 0.60), control1: p(0.84, 0.90), control2: p(0.40, 0.70))   // leading edge
                wing.addLine(to: p(0.10, 0.625))                                                      // tip chord
                wing.addCurve(to: p(0.34, 1.04), control1: p(0.20, 0.74), control2: p(0.22, 0.90))    // trailing edge
                wing.closeSubpath()
                ctx.fill(wing, with: .linearGradient(Gradient(stops: [.init(color: col(228, 231, 235), location: 0), .init(color: col(176, 182, 190), location: 0.55),
                                                                  .init(color: col(128, 136, 148), location: 1)]), startPoint: p(0.7, 1.0), endPoint: p(0.1, 0.6)))
                ctx.drawLayer { l in
                    l.clip(to: wing)
                    // flap and aileron seams
                    for (a0, b0, a1, b1) in [(0.62, 1.04, 0.13, 0.615), (0.50, 1.04, 0.12, 0.62)] as [(Double, Double, Double, Double)] {
                        var s = Path(); s.move(to: p(a0, b0)); s.addQuadCurve(to: p(a1, b1), control: p((a0 + a1) / 2 + 0.05, (b0 + b1) / 2 + 0.05))
                        l.stroke(s, with: .color(col(60, 66, 76, 0.55)), lineWidth: 1)
                    }
                    // soft sky reflection near the leading edge
                    var refl = Path(); refl.move(to: p(1.0, 1.0)); refl.addQuadCurve(to: p(0.17, 0.62), control: p(0.55, 0.78))
                    l.stroke(refl, with: .color(col(255, 255, 255, 0.35)), lineWidth: 5)
                    // haze with distance
                    l.fill(Path(CGRect(x: 0, y: 0.55 * h, width: w, height: 0.14 * h)), with: .color(col(190, 205, 222, 0.28)))
                }
                var edge = Path()
                edge.move(to: p(1.08, 1.04)); edge.addCurve(to: p(0.16, 0.60), control1: p(0.84, 0.90), control2: p(0.40, 0.70))
                ctx.stroke(edge, with: .color(col(250, 252, 255, 0.85)), lineWidth: 1.4)
                // tip lights: red on the left wing, green on the right, white strobe
                let night = min(1, grade.night + grade.blue * 0.7 + grade.golden * 0.15)
                if night > 0.05 {
                    let tip = p(0.11, 0.61)
                    let nav = mirror ? Color(.sRGB, red: 0.24, green: 1, blue: 0.47) : Color(.sRGB, red: 1, green: 0.24, blue: 0.2)
                    ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 9, y: tip.y - 9, width: 18, height: 18)), with: .radialGradient(Gradient(colors: [nav.opacity(0.85 * night), nav.opacity(0)]), center: tip, startRadius: 0, endRadius: 9))
                    let ph = t.truncatingRemainder(dividingBy: 1.3)
                    let strobe = (ph < 0.07 || (ph > 0.17 && ph < 0.24)) ? 1.0 : 0.0
                    if strobe > 0 {
                        ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 16, y: tip.y - 16, width: 32, height: 32)), with: .radialGradient(Gradient(colors: [.white.opacity(0.9 * night), .white.opacity(0)]), center: tip, startRadius: 0, endRadius: 16))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
