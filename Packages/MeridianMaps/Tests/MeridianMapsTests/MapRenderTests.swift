import XCTest
import SwiftUI
import MeridianCore
@testable import MeridianMaps

/// Renders the map-only layers of the design artboards (see docs: S10, S10B, S16*, S35) to PNG in `MAPS_OUT`,
/// for comparison with the canvas renders. Also measures draw time.
@MainActor
final class MapRenderTests: XCTestCase {
    static let size = CGSize(width: 1280, height: 800)

    override class func setUp() { RenderSupport.registerFonts() }

    // Camera values read from the design artboards (translate/scale of `.eu`), as center + zoom of a 1280 x 800 view.
    static let s10b = (center: Coordinate(latitude: 49.536477574, longitude: -0.453250000), zoom: 1.25)
    static let s16 = (center: Coordinate(latitude: 50.020918, longitude: 0.935417), zoom: 2.16026)

    private func europe(_ style: MapStyle, _ theme: MapTheme, _ cam: (center: Coordinate, zoom: Double), labels: Bool = true) -> some View {
        EuropeMapView(style: style, theme: theme, center: cam.center, zoom: cam.zoom, size: Self.size, showsLabels: labels)
    }

    private func save<V: View>(_ v: V, _ name: String) throws {
        let img = try XCTUnwrap(RenderSupport.render(v, size: Self.size))
        RenderSupport.writePNG(img, name: name)
    }

    func testRenderEuropeArtboards() throws {
        try save(europe(.terra, .dark, Self.s10b), "m_s10b_terra")
        try save(europe(.mono, .light, Self.s10b), "m_s10b_mono_light")
        try save(europe(.terra, .light, Self.s10b), "m_s10b_terra_light")
        for style in MapStyle.allCases {
            try save(europe(style, .dark, Self.s16), "m_s16_\(style.rawValue)")
        }
        try save(europe(.terra, .light, Self.s16), "m_s16_terra_light")
        try save(europe(.mono, .light, Self.s16), "m_s16_mono_light")
        try save(europe(.terra, .dark, (Coordinate(latitude: 51.47, longitude: -0.45), 1.9)), "m_terra")
    }

    func testRenderGlobeArtboards() throws {
        // S10 home: Globe 2200 on --bg-0, LHR, lat 13.47, no graticule/labels/atmosphere
        let s10 = ZStack(alignment: .topLeading) {
            Color(red: 6 / 255, green: 8 / 255, blue: 13 / 255)
            GlobeView(lon: -0.4543, lat: 13.47, size: 2200, theme: .dark, showsGraticule: false, showsAtmosphere: false, showsLabels: false)
                .offset(x: -460, y: 36)
        }
        try save(s10, "g_s10")
        let s10l = ZStack(alignment: .topLeading) {
            Color(red: 237 / 255, green: 233 / 255, blue: 225 / 255)
            GlobeView(lon: -0.4543, lat: 13.47, size: 2200, theme: .light, showsGraticule: false, showsAtmosphere: false, showsLabels: false)
                .offset(x: -460, y: 36)
        }
        try save(s10l, "g_s10_light")
        // light globe with graticule + atmosphere + visited layers, no routes (bare background: the page body is white)
        let s35l = ZStack(alignment: .topLeading) {
            Color.white
            GlobeView(lon: -8, lat: 36, size: 900, theme: .light, visited: true).offset(x: 90, y: -50)
        }
        try save(s35l, "g_s35_light")

        // S35: Globe 900 at (90, -50) on --m-sea with a soft radial wash; frequency view at t = 1
        let routes: [(String, String, Int)] = [
            ("LHR", "CDG", 14), ("LHR", "AMS", 9), ("LHR", "DUB", 6), ("LHR", "FRA", 5), ("LHR", "IST", 4), ("LHR", "MAD", 3), ("LHR", "CAI", 2),
            ("LHR", "JFK", 3), ("LHR", "DXB", 2), ("IST", "ESB", 3), ("ESB", "ADB", 2), ("FRA", "IST", 2), ("JFK", "BOS", 4), ("BOS", "YYZ", 2),
            ("YYZ", "SFO", 2), ("SIN", "SYD", 1), ("DXB", "DOH", 2), ("AMS", "BCN", 2),
        ]
        let thresholds = [0.04, 0.10, 0.22, 0.30, 0.38, 0.46, 0.55, 0.60, 0.66, 0.40, 0.44, 0.48, 0.64, 0.70, 0.76, 0.82, 0.88, 0.93]
        var gr: [GlobeRoute] = []
        for (i, r) in routes.enumerated() where thresholds[i] <= 1 + 1e-6 {
            let fresh = 1 - thresholds[i] < 0.07
            let col: Color = r.2 >= 6 ? RGBA(hex: 0x8BF3D8).color : r.2 >= 3 ? RGBA(hex: 0x6AB7FF).color : RGBA(hex: 0x9FB2FF).color
            if let route = GlobeRoute(from: r.0, to: r.1, airports: .design, color: fresh ? .white : col, width: 1 + min(2.4, Double(r.2) * 0.16), opacity: fresh ? 0.95 : 0.78, lift: 0.08) {
                gr.append(route)
            }
        }
        let tops: [(String, Double)] = [("LHR", 38), ("CDG", 17), ("AMS", 12), ("IST", 10), ("JFK", 8), ("FRA", 7), ("DUB", 7), ("MAD", 5)]
        let gp = tops.compactMap { GlobePin(code: $0.0, airports: .design, radius: 2.6 + $0.1 / 38 * 2.4) }
        let sea = MapPalette.resolve(style: .terra, theme: .dark).sea.color
        let s35 = ZStack(alignment: .topLeading) {
            sea
            Canvas { ctx, size in
                var g = ctx
                let cx = 0.45 * size.width, cy = 0.5 * size.height, rx = 0.7 * size.width, ry = 0.7 * size.height
                g.translateBy(x: cx, y: cy); g.scaleBy(x: rx, y: ry)
                g.fill(Path(CGRect(x: -cx / rx, y: -cy / ry, width: size.width / rx, height: size.height / ry)),
                       with: .radialGradient(Gradient(stops: [.init(color: RGBA(70, 92, 190, 0.22).color, location: 0), .init(color: RGBA(70, 92, 190, 0).color, location: 0.7)]), center: .zero, startRadius: 0, endRadius: 1))
            }
            GlobeView(lon: -8, lat: 36, size: 900, theme: .dark, routes: gr, pins: gp, visited: true)
                .offset(x: 90, y: -50)
        }
        try save(s35, "g_s35")
    }

    // MARK: performance

    /// Median wall time (ms) of rendering a view to a 1280 x 800 bitmap, camera changing every iteration (no caching).
    private func medianMs(scale: CGFloat = 1, _ make: (Int) -> AnyView, iterations: Int = 30) -> Double {
        var times = [Double]()
        for i in 0..<(iterations + 3) {
            let t0 = CFAbsoluteTimeGetCurrent()
            if let img = RenderSupport.render(make(i), size: Self.size, scale: scale) { RenderSupport.rasterize(img) }
            if i >= 3 { times.append((CFAbsoluteTimeGetCurrent() - t0) * 1000) }
        }
        return times.sorted()[times.count / 2]
    }

    func testPerformance() throws {
        MapResources.preload()
        var report = ""
        for style in MapStyle.allCases {
            for z in [0.5, 1.9, 7.0] {
                let ms = medianMs { i in
                    AnyView(EuropeMapView(style: style, theme: .dark, center: Coordinate(latitude: 50 + Double(i) * 0.05, longitude: 1 + Double(i) * 0.1),
                                          zoom: z + Double(i % 5) * 0.01, size: Self.size))
                }
                report += String(format: "Europe %@ zoom %.1f: %.1f ms\n", style.rawValue, z, ms)
            }
        }
        let retina = medianMs(scale: 2) { i in
            AnyView(EuropeMapView(style: .satellite, theme: .dark, center: Coordinate(latitude: 50 + Double(i) * 0.05, longitude: 1), zoom: 1.9, size: Self.size))
        }
        report += String(format: "Europe satellite zoom 1.9 @2x (2560x1600): %.1f ms\n", retina)
        let g = medianMs { i in
            AnyView(GlobeView(lon: -8 + Double(i), lat: 36, size: 900, theme: .dark, visited: true))
        }
        report += String(format: "Globe 900 visited %.1f ms\n", g)
        print(report)
        try report.write(to: RenderSupport.outDir.appendingPathComponent("perf.txt"), atomically: true, encoding: .utf8)
    }

    func testParsePerformance() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "map-europe-land", withExtension: "svg"))
        let svg = try String(contentsOf: url, encoding: .utf8)
        let t0 = CFAbsoluteTimeGetCurrent()
        let path = SVGPathParser.path(svg: svg)
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        print(String(format: "parse land svg %.2f ms, bounds %@", ms, "\(path.boundingRect)"))
        XCTAssertFalse(path.isEmpty)
        XCTAssertLessThan(ms, 200)
    }
}
