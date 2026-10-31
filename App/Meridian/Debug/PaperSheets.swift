import SwiftUI
import MeridianUI

/// Contact sheets of the paper components, laid out exactly like the reference pages used for
/// Scripts/compare.py (docs/design/paper-components.md). Debug routes: paper-pass, paper-pass2..4, paper-card, ...
struct PaperSheet<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var paperBackground = false
    let content: Content
    init(paperBackground: Bool = false, @ViewBuilder _ content: () -> Content) {
        self.paperBackground = paperBackground
        self.content = content()
    }
    var body: some View {
        ZStack(alignment: .topLeading) {
            if paperBackground { MRPalette.dark.paper.color }
            else { (scheme == .dark ? MRPalette.dark.bg0.color : MRPalette.light.bg0.color) }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }
}

extension View {
    func sheetAt(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }
}

enum PaperSamples {
    static func route(_ to: String, _ city: String, _ c: PaperCoordinate, _ sc: PaperScenario, km: Int, min: Int) -> BoardingPassModel {
        BoardingPassModel(originCode: "LHR", originCity: "London", destinationCode: to, destinationCity: city,
                          originCoordinate: BoardingPassModel.lhrCoordinate, destinationCoordinate: c,
                          durationMinutes: min, distanceKm: km, scenario: sc)
    }
    static var study: BoardingPassModel { var m = BoardingPassModel.sample; m.scenario = .study; return m }
    static var read: BoardingPassModel { var m = BoardingPassModel.sample; m.scenario = .read; return m }
    static var cairo: BoardingPassModel { route("CAI", "Cairo", .init(lat: 30.1219, lon: 31.4056), .work, km: 3532, min: 289) }
    static var ams: BoardingPassModel { route("AMS", "Amsterdam", .init(lat: 52.3105, lon: 4.7683), .code, km: 370, min: 44) }
    static var mad: BoardingPassModel { route("MAD", "Madrid", .init(lat: 40.4983, lon: -3.5676), .read, km: 1243, min: 111) }
    static var dxb: BoardingPassModel { route("DXB", "Dubai", .init(lat: 25.2532, lon: 55.3657), .create, km: 5497, min: 441) }
    static var jfk: BoardingPassModel { route("JFK", "New York", .init(lat: 40.6413, lon: -73.7781), .meditate, km: 5540, min: 444) }
}

struct PaperPassSheet: View {
    let variant: Int
    var body: some View {
        PaperSheet {
            switch variant {
            case 1:
                BoardingPassView(.sample).sheetAt(40, 40)
                BoardingPassView(.sample, state: .torn).sheetAt(440, 40)
                BoardingPassView(.sample, state: .landed, side: .back).sheetAt(840, 40)
            case 2:
                BoardingPassView(.sample, state: .boarding, scale: 0.8).sheetAt(24, 30)
                BoardingPassView(.sample, state: .inflight(0.6), scale: 0.8).sheetAt(324, 30)
                BoardingPassView(.sample, state: .landed, scale: 0.8).sheetAt(624, 30)
                BoardingPassView(.sample, state: .diverted, scale: 0.8).sheetAt(924, 30)
            case 3:
                BoardingPassView(PaperSamples.study, state: .group, scale: 0.8).sheetAt(24, 30)
                BoardingPassView(PaperSamples.read, state: .locked, scale: 0.8).sheetAt(324, 30)
                BoardingPassView(PaperSamples.cairo, scale: 0.8).sheetAt(624, 30)
                BoardingPassView(.sample, state: .printing(0.55), scale: 0.8).sheetAt(924, 30)
            default:
                BoardingPassView(PaperSamples.ams, scale: 0.8).sheetAt(24, 30)
                BoardingPassView(PaperSamples.mad, scale: 0.8).sheetAt(324, 30)
                BoardingPassView(PaperSamples.dxb, scale: 0.8).sheetAt(624, 30)
                BoardingPassView(PaperSamples.jfk, scale: 0.8).sheetAt(924, 30)
            }
        }
    }
}
