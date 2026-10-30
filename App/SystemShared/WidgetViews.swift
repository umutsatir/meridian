import MeridianUI
import SwiftUI

/// Colors of one widget theme (`M04` `T(k)`): dark and light.
struct WidgetTheme {
    var dark: Bool
    var a1, a2, track, arc, dot, halo, text: Color

    static func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
    static let darkTheme = WidgetTheme(dark: true, a1: c(106, 183, 255), a2: c(139, 243, 216), track: .white.opacity(0.16), arc: .white.opacity(0.55),
                                       dot: .white, halo: c(106, 183, 255, 0.32), text: c(243, 245, 250))
    static let lightTheme = WidgetTheme(dark: false, a1: c(30, 107, 255), a2: c(24, 199, 160), track: c(20, 22, 28, 0.12), arc: c(20, 22, 28, 0.45),
                                        dot: c(20, 22, 28), halo: c(30, 107, 255, 0.24), text: c(20, 22, 28))
    static func resolve(_ scheme: ColorScheme) -> WidgetTheme { scheme == .dark ? darkTheme : lightTheme }

    var gradient: LinearGradient { LinearGradient(colors: [a1, a2], startPoint: .topLeading, endPoint: .bottomTrailing) }
    var hGradient: LinearGradient { LinearGradient(colors: [a1, a2], startPoint: .leading, endPoint: .trailing) }
    var liveDot: Color { dark ? Self.c(106, 183, 255) : Self.c(30, 107, 255) }
    var background: LinearGradient {
        dark ? LinearGradient(colors: [Self.c(24, 32, 60, 0.92), Self.c(10, 14, 28, 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing)
             : LinearGradient(colors: [.white.opacity(0.94), Self.c(250, 246, 238, 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum WidgetFamilyKind { case small, medium, large
    var size: CGSize {
        switch self {
        case .small: CGSize(width: 158, height: 158)
        case .medium: CGSize(width: 338, height: 158)
        case .large: CGSize(width: 338, height: 354)
        }
    }
}

/// `.w`: the card chrome. In the widget extension `drawsChrome` is false (the system supplies the container).
struct WidgetCard<Content: View>: View {
    var theme: WidgetTheme
    var family: WidgetFamilyKind
    var drawsChrome = true
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        ZStack(alignment: .topLeading) { content }
            .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
            .foregroundStyle(theme.text)
            .background { if drawsChrome { shape.fill(theme.background) } }
            .overlay {
                if drawsChrome {
                    shape.strokeBorder(theme.dark ? Color.white.opacity(0.12) : WidgetTheme.c(20, 22, 28, 0.08), lineWidth: 1)
                }
            }
            .clipShape(shape)
            .shadow(color: drawsChrome ? (theme.dark ? .black.opacity(0.35) : WidgetTheme.c(60, 40, 70, 0.22)) : .clear, radius: 20, y: 18)
    }
}

private func eyebrow(_ text: String) -> some View {
    Text(text).font(MRFonts.font(.ui, size: 10, weight: 600)).tracking(1.2).textCase(.uppercase).opacity(0.62).frame(height: 12)
}
private func serif(_ size: CGFloat, _ text: String) -> some View {
    Text(text).font(MRFonts.font(.serif, size: size, weight: 500)).tracking(-0.02 * size).monospacedDigit()
}
private func mono(_ size: CGFloat, _ text: String) -> some View {
    Text(text).font(MRFonts.font(.mono, size: size, weight: 500)).opacity(0.7)
}
private func mmss(_ sec: Double) -> String {
    let s = max(0, Int(sec.rounded()))
    return String(format: "%02d:%02d", s / 60, s % 60)
}

/// The countdown: ticks by itself in the widget (`Text(timerInterval:)`), static on the artboard and while paused.
struct WidgetCountdown: View {
    var live: WidgetSnapshot.Live
    var size: CGFloat
    var ticking: Bool

    var body: some View {
        if ticking, let eta = live.eta, !live.paused, eta > .now {
            Text(timerInterval: Date.now...eta, countsDown: true)
                .font(MRFonts.font(.serif, size: size, weight: 500)).tracking(-0.02 * size).monospacedDigit()
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            serif(size, mmss(live.remainingSec))
        }
    }
}

struct WidgetNextCardSmall: View {
    var snapshot: WidgetSnapshot
    var theme: WidgetTheme
    var drawsChrome = true

    var body: some View {
        let card = snapshot.nextCard
        WidgetCard(theme: theme, family: .small, drawsChrome: drawsChrome) {
            eyebrow("Next card").padding(.leading, 16).padding(.top, 14)
            Circle().stroke(theme.track, lineWidth: 9).frame(width: 76, height: 76).position(x: 79, y: 84)
            Circle().trim(from: 0, to: Double(card.percent) / 100).stroke(theme.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90)).frame(width: 76, height: 76).position(x: 79, y: 84)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                serif(26, "\(card.percent)")
                Text("%").font(MRFonts.font(.ui, size: 12, weight: 500)).opacity(0.62)
            }
            .frame(width: 158).offset(y: 66 - 1)
            HStack(alignment: .firstTextBaseline) {
                Text(card.name).font(MRFonts.font(.ui, size: 11, weight: 600))
                Spacer()
                mono(10, "\(Self.grouped(card.kmToGo)) km")
            }
            .padding(.horizontal, 16).frame(width: 158).offset(y: 158 - 11 - 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next card: \(card.name), \(card.percent) percent, \(Self.grouped(card.kmToGo)) kilometres to go")
    }

    static func grouped(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct WidgetLiveSmall: View {
    var live: WidgetSnapshot.Live
    var theme: WidgetTheme
    var drawsChrome = true
    var ticking = false

    var body: some View {
        WidgetCard(theme: theme, family: .small, drawsChrome: drawsChrome) {
            HStack(spacing: 6) {
                Circle().fill(theme.liveDot).frame(width: 6, height: 6)
                eyebrow(live.paused ? "Paused" : "In flight")
            }
            .padding(.leading, 16).padding(.top, 14)
            VStack(alignment: .leading, spacing: 4) {
                WidgetCountdown(live: live, size: 38, ticking: ticking).frame(height: 40, alignment: .leading)
                mono(11, "to \(live.destinationCity) · \(live.destinationCode)").frame(height: 14)
            }
            .padding(.horizontal, 16).offset(y: 42)
            VStack(spacing: 6) {
                progressBar(theme, live.progress, knob: false)
                HStack { mono(10, live.originCode); Spacer(); mono(10, "\(Int((live.progress * 100).rounded())) %") }
            }
            .padding(.horizontal, 16).frame(width: 158).offset(y: 158 - 16 - 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("In flight to \(live.destinationCity), \(Int(live.remainingSec) / 60) minutes \(Int(live.remainingSec) % 60) seconds left")
    }
}

private func progressBar(_ theme: WidgetTheme, _ p: Double, knob: Bool) -> some View {
    GeometryReader { g in
        ZStack(alignment: .leading) {
            Capsule().fill(theme.track).frame(height: 5)
            Capsule().fill(theme.hGradient).frame(width: g.size.width * p, height: 5)
            if knob {
                Circle().fill(theme.dot).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(theme.halo, lineWidth: 3).padding(-3))
                    .offset(x: g.size.width * p - 6)
            }
        }
        .frame(height: g.size.height)
    }
    .frame(height: knob ? 12 : 5)
}

struct WidgetLongestMedium: View {
    var snapshot: WidgetSnapshot
    var theme: WidgetTheme
    var drawsChrome = true

    var body: some View {
        let l = snapshot.longest ?? .init(originCode: "—", destinationCode: "—", km: 0, durationText: "", aroundEarth: 0)
        WidgetCard(theme: theme, family: .medium, drawsChrome: drawsChrome) {
            eyebrow("Longest route").padding(.leading, 16).padding(.top, 14)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    serif(42, WidgetNextCardSmall.grouped(l.km))
                    Text("km").font(MRFonts.font(.ui, size: 12, weight: 500)).opacity(0.62)
                }
                .frame(height: 44, alignment: .leading)
                mono(11, "\(l.originCode) → \(l.destinationCode) · \(l.durationText)").frame(height: 14)
            }
            .offset(x: 16, y: 34)
            Canvas { ctx, _ in
                var dashed = Path()
                dashed.move(to: CGPoint(x: 178, y: 112))
                dashed.addCurve(to: CGPoint(x: 316, y: 92), control1: CGPoint(x: 214, y: 40), control2: CGPoint(x: 276, y: 36))
                ctx.stroke(dashed, with: .color(theme.arc), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))
                var solid = Path()
                solid.move(to: CGPoint(x: 178, y: 112))
                solid.addCurve(to: CGPoint(x: 296, y: 64), control1: CGPoint(x: 214, y: 40), control2: CGPoint(x: 262, y: 34))
                ctx.stroke(solid, with: .linearGradient(Gradient(colors: [theme.a1, theme.a2]), startPoint: CGPoint(x: 178, y: 0), endPoint: CGPoint(x: 296, y: 158)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: 173.5, y: 107.5, width: 9, height: 9)), with: .color(theme.dot))
                ctx.stroke(Path(ellipseIn: CGRect(x: 312.5 - 0.0, y: 87.5, width: 9, height: 9)), with: .color(WidgetTheme.c(255, 181, 71)), lineWidth: 2)
            }
            .frame(width: 338, height: 158).accessibilityHidden(true)
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(theme.track, lineWidth: 3)
                    Circle().trim(from: 0, to: min(1, l.aroundEarth)).stroke(theme.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16).frame(width: 22, height: 22)
                HStack(spacing: 4) {
                    Text("Around Earth").font(MRFonts.font(.ui, size: 12, weight: 600))
                    Text(String(format: "%.1f×", l.aroundEarth)).font(MRFonts.font(.serif, size: 15, weight: 500))
                }
            }
            .padding(.horizontal, 16).frame(width: 338, alignment: .leading).offset(y: 158 - 12 - 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Longest route: \(l.originCode) to \(l.destinationCode), \(l.km) kilometres, \(l.durationText). Around Earth \(String(format: "%.1f", l.aroundEarth)) times.")
    }
}

/// `wrap` lets the extension turn the label into an App Intents button.
struct WidgetLiveMedium: View {
    var live: WidgetSnapshot.Live
    var theme: WidgetTheme
    var drawsChrome = true
    var ticking = false
    var etaText = "ETA 10:42"
    var pauseWrap: (AnyView) -> AnyView = { $0 }
    var openWrap: (AnyView) -> AnyView = { $0 }

    var body: some View {
        WidgetCard(theme: theme, family: .medium, drawsChrome: drawsChrome) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(theme.liveDot).frame(width: 6, height: 6)
                    eyebrow("\(live.paused ? "Paused" : "In flight") · \(live.flightNumber)")
                }
                Spacer()
                mono(11, etaText)
            }
            .padding(.horizontal, 16).padding(.top, 14).frame(width: 338)
            VStack(alignment: .leading, spacing: 2) {
                WidgetCountdown(live: live, size: 44, ticking: ticking).frame(height: 46, alignment: .leading)
                mono(11, "\(live.originCode) → \(live.destinationCode) · \(live.kmToGo) km to go").frame(height: 14)
            }
            .frame(width: 200, alignment: .leading).offset(x: 16, y: 36)
            VStack(alignment: .trailing, spacing: 8) {
                pauseWrap(AnyView(pill(icon: live.paused ? .play : .pause, text: live.paused ? "Resume" : "Pause")))
                openWrap(AnyView(pill(icon: nil, text: "Open")))
            }
            .frame(width: 338 - 16, alignment: .trailing).offset(y: 44)
            progressBar(theme, live.progress, knob: true).padding(.horizontal, 16).frame(width: 338).offset(y: 158 - 15 - 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("In flight to \(live.destinationCity), \(Int(live.remainingSec) / 60) minutes \(Int(live.remainingSec) % 60) seconds left")
    }

    private func pill(icon: MRIconName?, text: String) -> some View {
        HStack(spacing: 6) {
            if let icon { MRIcon(icon, size: 12) }
            Text(text).font(MRFonts.font(.ui, size: 12, weight: 600))
        }
        .padding(.horizontal, 12).frame(height: 26)
        .background(Capsule().fill(theme.dark ? Color.white.opacity(0.14) : WidgetTheme.c(20, 22, 28, 0.08)))
        .foregroundStyle(theme.text)
    }
}

struct WidgetWeekLarge: View {
    var snapshot: WidgetSnapshot
    var theme: WidgetTheme
    var drawsChrome = true

    var body: some View {
        let total = snapshot.weekHours.reduce(0, +)
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        WidgetCard(theme: theme, family: .large, drawsChrome: drawsChrome) {
            HStack(alignment: .firstTextBaseline) { eyebrow("This week"); Spacer(); mono(11, snapshot.weekRange) }
                .padding(.horizontal, 16).padding(.top, 14).frame(width: 338)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                serif(40, String(format: "%.1f", total))
                Text("hours in flight").font(MRFonts.font(.ui, size: 12, weight: 500)).opacity(0.62)
            }
            .offset(x: 16, y: 14 + 12 + 6)
            Canvas { ctx, _ in
                var base = Path(); base.move(to: CGPoint(x: 0, y: 112)); base.addLine(to: CGPoint(x: 306, y: 112))
                ctx.stroke(base, with: .color(theme.track), lineWidth: 1)
                var dash = Path(); dash.move(to: CGPoint(x: 0, y: 48)); dash.addLine(to: CGPoint(x: 306, y: 48))
                ctx.stroke(dash, with: .color(theme.track), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                for (i, v) in snapshot.weekHours.enumerated() {
                    let h = max(8, v / 4.5 * 100), x = Double(i) * (306 - 30) / 6
                    let r = CGRect(x: x, y: 112 - h, width: 30, height: h)
                    let fill: GraphicsContext.Shading = i == snapshot.todayIndex
                        ? .linearGradient(Gradient(colors: [theme.a1, theme.a2]), startPoint: CGPoint(x: x, y: 112 - h), endPoint: CGPoint(x: x + 30, y: 112))
                        : .color(theme.dark ? .white.opacity(0.2) : WidgetTheme.c(20, 22, 28, 0.16))
                    ctx.fill(Path(roundedRect: r, cornerRadius: 8, style: .continuous), with: fill)
                }
            }
            .frame(width: 306, height: 150).offset(x: 16, y: 96).accessibilityHidden(true)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(days[i]).font(MRFonts.font(.mono, size: 10, weight: i == snapshot.todayIndex ? 700 : 500))
                        .opacity(i == snapshot.todayIndex ? 1 : 0.7).frame(width: 30)
                    if i < 6 { Spacer(minLength: 0) }
                }
            }
            .frame(width: 306).offset(x: 16, y: 230)
            VStack(spacing: 12) {
                Rectangle().fill(theme.track).frame(height: 1)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        eyebrow("Current streak")
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            serif(30, "\(snapshot.streak)")
                            Text("days").font(MRFonts.font(.ui, size: 12, weight: 500)).opacity(0.62)
                        }
                        .frame(height: 32)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        ForEach(0..<12, id: \.self) { i in
                            Circle().frame(width: 8, height: 8)
                                .foregroundStyle(i == 11 ? (theme.dark ? WidgetTheme.c(139, 243, 216) : WidgetTheme.c(24, 199, 160))
                                                         : (theme.dark ? Color.white.opacity(0.55) : WidgetTheme.c(20, 22, 28, 0.45)))
                        }
                    }
                }
            }
            .padding(.horizontal, 16).frame(width: 338).offset(y: 354 - 14 - 12 - 1 - 12 - 50 + 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week, \(String(format: "%.1f", total)) hours. Current streak, \(snapshot.streak) days.")
    }
}
