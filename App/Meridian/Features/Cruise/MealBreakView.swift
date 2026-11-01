import AppKit
import MeridianCore
import MeridianUI
import SwiftUI

/// Meal service overlay (`Meal.dc.html`, S20 to S20D): the seat-back screen of the cabin scene with the break
/// chooser, the running timer, the open-ended break and the "time's up" banner.
///
/// The cabin illustration (window, seat back, tray with coffee, bread, salad, glass, napkin) is the canvas artwork
/// itself, rendered once from `Meal.dc.html` without its screen layer into `meal-<tray>.jpg`. The screen, texts,
/// timer and banner are live SwiftUI.
struct MealBreakView: View {
    enum Mode { case choose, timed, open, over }
    enum Kind { case timed, open }

    var frame: CruiseFrame
    var initialMode: Mode = .choose
    var remain = 272
    var elapsed = 372
    var length = 5
    var kind: Kind = .timed
    var notify = true
    var tray = "full"
    var onResume: () -> Void = {}
    var onStart: (Kind, Int) -> Void = { _, _ in }
    /// Artboards draw a fixed time; the live overlay counts.
    var live = true

    @State private var mode: Mode = .choose
    @State private var remaining = 272
    @State private var elapsedSec = 372
    @State private var len = 5
    @State private var kindSel: Kind = .timed
    @State private var notifySel = true
    @State private var seeded = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let k = min(geo.size.width / 1280, geo.size.height / 800)
            sceneBody
                .scaleEffect(k, anchor: .topLeading)
                .frame(width: 1280 * k, height: 800 * k, alignment: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color(.sRGB, red: 0x0A / 255, green: 0x0C / 255, blue: 0x12 / 255))
        }
    }

    private var sceneBody: some View {
        ZStack(alignment: .topLeading) {
            Color(.sRGB, red: 0x0A / 255, green: 0x0C / 255, blue: 0x12 / 255)
            if let img = Self.image(mode == .over ? "clear" : (mode == .open ? "half" : tray)) {
                Image(nsImage: img).resizable().interpolation(.high).frame(width: 1280, height: 800)
            }
            screen
                .frame(width: 520, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .offset(x: 430, y: 210)
            Text("Seat \(frame.gate.isEmpty ? "1A" : "1A")\n\(frame.flightNumber) · \(frame.origin.iata) → \(frame.destination?.iata ?? "")")
                .font(.mr(.mono, size: 11)).tracking(0.66).lineSpacing(5)
                .foregroundStyle(cruiseRGBA(231, 236, 246, 0.5))
                .offset(x: 28, y: 800 - 18 - 32)
            if mode == .over && notifySel { banner }
        }
        .frame(width: 1280, height: 800, alignment: .topLeading)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            mode = initialMode; remaining = remain; elapsedSec = elapsed; len = length; kindSel = kind; notifySel = notify
        }
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                switch mode {
                case .timed:
                    remaining -= 1
                    if remaining <= 0 { mode = .over; elapsedSec = 0 }
                case .open, .over: elapsedSec += 1
                case .choose: break
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meal service")
    }

    @MainActor private static var cache: [String: NSImage] = [:]
    @MainActor private static func image(_ tray: String) -> NSImage? {
        if let c = cache[tray] { return c }
        guard let url = Bundle.main.url(forResource: "meal-\(tray)", withExtension: "jpg"), let i = NSImage(contentsOf: url) else { return nil }
        cache[tray] = i
        return i
    }

    private func mm(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }
    private func eta(_ m: Int) -> String { let t = frame.etaMinuteOfDay + m; return String(format: "%02d:%02d", t / 60 % 24, t % 60) }

    // MARK: screen

    private var screen: some View {
        let p = MRPalette.resolve(scheme)
        return ZStack {
            CSSEllipse(cx: 0.5, cy: 0, rx: 0.9, ry: 0.7, stops: [.init(color: cruiseRGBA(106, 183, 255, 0.14), location: 0), .init(color: .clear, location: 0.7)])
            VStack(spacing: 0) {
                if mode == .choose { chooser(p) } else { run(p) }
            }
            .padding(.top, 20).padding(.horizontal, 26).padding(.bottom, 18)
            .frame(width: 520, height: 280, alignment: .top)
            LinearGradient(stops: [.init(color: .white.opacity(0.07), location: 0), .init(color: .white.opacity(0), location: 0.38)],
                           startPoint: cssPt(115).0, endPoint: cssPt(115).1)
                .allowsHitTesting(false)
        }
        .foregroundStyle(p.text1.color)
    }

    private func cssPt(_ deg: Double) -> (UnitPoint, UnitPoint) {
        let a = deg * .pi / 180
        let dx = sin(a), dy = -cos(a)
        let len = abs(520 * sin(a)) + abs(280 * cos(a))
        return (UnitPoint(x: (260 - dx * len / 2) / 520, y: (140 - dy * len / 2) / 280), UnitPoint(x: (260 + dx * len / 2) / 520, y: (140 + dy * len / 2) / 280))
    }

    private func chooser(_ p: MRPalette) -> some View {
        VStack(spacing: 0) {
            Text("Meal service").mrText(.title2).frame(height: 30)
            Text("Your flight goes on hold while you’re away.").mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 3).frame(height: 18)
            HStack(spacing: 12) {
                card(on: kindSel == .open, icon: .pause, title: "Until I’m back", p: p) {
                    Text("No timer. Pause, handle things, return when you’re ready.").font(.mr(.ui, size: 12)).foregroundStyle(p.text3.color).lineSpacing(0)
                        .fixedSize(horizontal: false, vertical: true)
                } pick: { kindSel = .open }
                card(on: kindSel == .timed, icon: .clock, title: "Set a timer", p: p) {
                    HStack(spacing: 6) {
                        ForEach([5, 10, 15, 20], id: \.self) { n in
                            MealChip(text: String(n), on: kindSel == .timed && len == n) { kindSel = .timed; len = n }
                        }
                    }
                    .padding(.top, 4)
                    Text("minutes · a banner rings when time is up").font(.mr(.ui, size: 12)).foregroundStyle(p.text3.color)
                        .fixedSize(horizontal: false, vertical: true)
                } pick: { kindSel = .timed }
            }
            .padding(.top, 16)
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(get: { notifySel && kindSel != .open }, set: { notifySel = $0 })).toggleStyle(MRToggleStyle()).labelsHidden()
                    .accessibilityLabel("Notify me when the break ends")
                Text("Notify me when it ends").font(.mr(.ui, size: 13, weight: 500)).foregroundStyle(p.text2.color).frame(maxWidth: .infinity, alignment: .leading)
                Button("Cancel") { onResume() }.buttonStyle(MRButtonStyle(.tertiary, size: .sm))
                Button("Start break") { startBreak() }.buttonStyle(MRButtonStyle(.primary, size: .sm))
            }
            .opacity(kindSel == .open ? 0.4 : 1).allowsHitTesting(true)
            .padding(.top, 14)
        }
    }

    private func card<C: View>(on: Bool, icon: MRIconName, title: String, p: MRPalette, @ViewBuilder _ body: () -> C, pick: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MRIcon(icon, size: 16).foregroundStyle(p.accent1.color)
                Text(title).font(.mr(.ui, size: 14, weight: 600)).frame(height: 18)
            }
            body()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120, alignment: .topLeading)
        .background(shape.fill(on ? cruiseRGBA(106, 183, 255, 0.14) : p.fill1.color))
        .overlay(shape.strokeBorder(on ? p.accent1.color : p.strokeHair.color, lineWidth: on ? 1.5 : 1))
        .contentShape(shape)
        .onTapGesture(perform: pick)
        .accessibilityAddTraits(.isButton).accessibilityAddTraits(on ? .isSelected : [])
    }

    private func run(_ p: MRPalette) -> some View {
        let over = mode == .over, open = mode == .open
        let title = over ? "Meal service is over" : (open ? "On break" : "Meal service — \(len) minute break")
        let sub = over ? "Back to your seat whenever you’re ready." : (open ? "Take your time. Your flight waits where you left it." : "Stretch, drink some water. Your flight is on hold.")
        let amber = Color(.sRGB, red: 1, green: 0xC2 / 255, blue: 0x7A / 255)
        let pillText = over ? "Time’s up" : "Flight on hold"
        let pillInk = over ? amber : p.accent1.color
        let pillBg = over ? cruiseRGBA(255, 181, 71, 0.14) : cruiseRGBA(106, 183, 255, 0.14)
        let pillRing = over ? cruiseRGBA(255, 181, 71, 0.4) : cruiseRGBA(106, 183, 255, 0.35)
        let timeText = over ? "+\(elapsedSec / 60):\(String(format: "%02d", elapsedSec % 60))" : (open ? mm(elapsedSec) : mm(remaining))
        let timeSize: CGFloat = over ? 48 : 56
        return VStack(spacing: 0) {
            HStack(spacing: 7) {
                BreathingDot(color: pillInk)
                Text(pillText).font(.mr(.ui, size: 11, weight: 600)).tracking(0.88).textCase(.uppercase)
            }
            .foregroundStyle(pillInk)
            .padding(.leading, 8).padding(.trailing, 10).frame(height: 24)
            .background(Capsule().fill(pillBg)).overlay(Capsule().strokeBorder(pillRing, lineWidth: 1))
            Text(title).mrText(.title2).padding(.top, 10).frame(height: 30 + 10, alignment: .bottom)
            Text(sub).mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 3).frame(height: 18 + 3, alignment: .bottom)
            Text(timeText).font(.mr(.mono, size: timeSize, weight: 500)).monospacedDigit()
                .foregroundStyle(over ? amber : p.text1.color)
                .padding(.top, over ? 16 : 14).padding(.bottom, over ? 6 : (open ? 4 : 10)).frame(height: timeSize + (over ? 22 : (open ? 18 : 24)))
            if mode == .timed {
                let pct = max(0, min(1, 1 - Double(remaining) / Double(len * 60)))
                Capsule().fill(p.fill2.color).frame(width: 260, height: 4)
                    .overlay(alignment: .leading) { Capsule().fill(p.accentGradient).frame(width: 260 * pct, height: 4) }
            }
            HStack(spacing: 12) {
                Button(over ? "+5 min" : (open ? "Set a timer" : "Skip break")) { secondary() }.buttonStyle(MRButtonStyle(.secondary))
                if mode == .timed { Button("Extend") { remaining += 300; len += 5 }.buttonStyle(MRButtonStyle(.primary)) }
                else { Button("Back to flight") { onResume() }.buttonStyle(MRButtonStyle(.primary)) }
            }
            .padding(.top, mode == .timed ? 18 : (open ? 20 : 18))
            HStack(spacing: 8) {
                MRIcon(over || open ? .clock : .bell, size: 13)
                Text(foot).font(.mr(.mono, size: 11))
            }
            .foregroundStyle(p.text3.color).padding(.top, 12)
        }
    }

    private var foot: String {
        switch mode {
        case .timed: return notifySel ? "Banner at 00:00 · ETA \(eta(0)) → \(eta(len))" : "No banner · ETA \(eta(0)) → \(eta(len))"
        case .open: return "so far · ETA moves while you’re away"
        default: return "over time, quietly counted · no penalty"
        }
    }

    private func secondary() {
        switch mode {
        case .timed: onResume()
        case .open: mode = .choose
        case .over: mode = .timed; remaining = 300; len = 5
        case .choose: break
        }
    }

    private func startBreak() {
        onStart(kindSel, len)
        if kindSel == .open { mode = .open; elapsedSec = 0 } else { mode = .timed; remaining = len * 60 }
    }

    // MARK: notification banner (time is up)

    private var banner: some View {
        let p = MRPalette.resolve(scheme)
        return HStack(alignment: .top, spacing: 12) {
            MRIcon(.mark, size: 24).foregroundStyle(Color(RGB(hex: "#04101A")))
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LinearGradient(colors: [Color(RGB(hex: "#6AB7FF")), Color(RGB(hex: "#4FE0C0"))], startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Meridian").font(.mr(.ui, size: 13, weight: 600))
                    Spacer()
                    Text("now").font(.mr(.ui, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                }
                .frame(height: 16)
                Text("Meal service is over").font(.mr(.ui, size: 14, weight: 600)).padding(.top, 2).frame(height: 20, alignment: .bottom)
                Text("Back to your seat. \(max(1, Int((Double(frame.remainingSec) / 60).rounded(.up)))) min to \(frame.destination?.city ?? "go").")
                    .font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 17)
                HStack(spacing: 8) {
                    MealChip(text: "+5 min", on: false, small: true) { secondary() }
                    MealChip(text: "Back to flight", on: true, small: true) { onResume() }
                }
                .padding(.top, 10)
            }
            .foregroundStyle(p.text1.color)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(width: 372)
        .mrGlass(cornerRadius: 22, elevation: .e3)
        .offset(x: 1280 - 24 - 372, y: 22)
        .accessibilityAddTraits(.isModal)
    }
}

private struct MealChip: View {
    let text: String
    let on: Bool
    var small = false
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hover = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let h: CGFloat = small ? 26 : 30
        Button(action: action) {
            Text(text)
                .font(small ? .mr(.ui, size: 12, weight: 600) : .mr(.mono, size: 13, weight: 600))
                .foregroundStyle(on ? Color(RGB(hex: "#04101A")) : (hover ? p.text1.color : p.text2.color))
                .padding(.horizontal, 10).frame(minWidth: small ? 0 : 46).frame(height: h)
                .background(Capsule().fill(on ? AnyShapeStyle(p.accentGradient) : AnyShapeStyle(hover ? p.fill3.color : p.fill2.color)))
                .overlay(Capsule().strokeBorder(p.strokeHair.color, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
        .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
    }
}

private struct BreathingDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
            let o = reduceMotion ? 1 : 0.5 + 0.5 * (1 - abs(cos(t * .pi)))
            Circle().fill(color).frame(width: 7, height: 7).opacity(o)
        }
    }
}
