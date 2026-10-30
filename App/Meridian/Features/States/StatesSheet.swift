import MeridianCruise
import MeridianUI
import MeridianCruise
import SwiftUI

/// S54: the state sheet (1280 x 1620): empty, error, loading and "Flight resumed".
/// The tiles are reusable: screens use `EmptyStateTiles` etc. inline, never as modals.
struct StatesSheet: View {
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 24), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            header
            section(L("Empty"), L("shown inside the normal screen, never as a modal")) { emptyTiles }
            section(L("Errors"), L("plain words, one action, never red unless data is at risk")) { errorTiles }
            section(L("Loading"), L("skeletons keep the final layout; shimmer 1.4 s; Reduce Motion = static fill")) { loadingTiles }
            section(L("Flight resumed"), L("shown at the top of the cruise screen, auto-dismisses after 8 s, never steals focus")) { resumed }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 64).padding(.top, 56).padding(.bottom, 64)
        .frame(width: 1280, height: 1620, alignment: .topLeading)
        .background(p.bg0.color)
        .foregroundStyle(p.text1.color)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("S54").mrText(.eyebrow).foregroundStyle(p.text2.color)
                Text(L("States")).font(.mr(.serif, size: 44, weight: 500)).tracking(-0.02 * 44).frame(height: 48, alignment: .leading).padding(.top, 6)
                Text(L("Nothing here shames you for having no data. Empty states say what will fill the space, errors say what still works, and loading never blocks the flight."))
                    .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color).frame(maxWidth: 620, alignment: .leading).padding(.top, 6)
            }
            Spacer()
            Text(L("Every button uses the kit’s hover, pressed, focus and disabled states. All tiles are 368 × 292."))
                .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text3.color).multilineTextAlignment(.trailing).frame(maxWidth: 340, alignment: .trailing)
        }
    }

    private func section<C: View>(_ title: String, _ note: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.mr(.ui, size: 11, weight: 600)).tracking(11 * 0.08).textCase(.uppercase).foregroundStyle(p.text2.color)
                Spacer()
                Text(note).font(.mr(.mono, size: 11, weight: 400)).foregroundStyle(p.text3.color).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    // MARK: Empty

    private var emptyTiles: some View {
        LazyVGrid(columns: cols, spacing: 24) {
            StateTile(id: L("Wallet · no flights"), title: L("No tickets yet. Your first flight will print here."), message: L("Pick a destination and a tag. The printer does the rest."), label: L("No flights yet")) {
                EmptyTicketArt()
            } actions: {
                Button(L("Plan a flight")) {}.buttonStyle(MRButtonStyle(.primary, size: .sm))
            }
            StateTile(id: L("Together · no friends"), title: L("Nobody on board yet."), message: L("Invite a friend to fly the same route at the same time. It shows status only, never chat."), label: L("No friends")) {
                EmptyFriendsArt()
            } actions: {
                Button(L("Invite a friend")) {}.buttonStyle(MRButtonStyle(.primary, size: .sm))
                Button(L("Learn how it works")) {}.buttonStyle(MRButtonStyle(.tertiary, size: .sm))
            }
            StateTile(id: L("Cards · none unlocked"), title: L("No cards yet."), message: L("Cards unlock as you fly. The first one arrives at 1,000 km."), label: L("No cards")) {
                EmptyCardArt()
            } actions: {
                Button(L("See all cards")) {}.buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
        }
    }

    // MARK: Errors

    private var errorTiles: some View {
        LazyVGrid(columns: cols, spacing: 24) {
            StateTile(id: L("No internet"), title: L("You’re offline."), message: L("Your flight keeps running. The map shows the last tiles it downloaded."), label: L("No internet"), role: .isStaticText) {
                IconBox(.wifiOff, tint: p.text2.color)
            } actions: {
                Button { } label: { HStack(spacing: 8) { MRIcon(.refresh, size: 14); Text(L("Try again")) } }.buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
            StateTile(id: L("iCloud off"), title: L("iCloud is off."), message: L("Flights are saved on this Mac only. Turn on iCloud to keep them on every device."), label: L("iCloud off banner")) {
                IconBox(.cloudOff, tint: p.amber.color)
            } actions: {
                Button(L("Open System Settings")) {}.buttonStyle(MRButtonStyle(.primary, size: .sm))
                Button(L("Not now")) {}.buttonStyle(MRButtonStyle(.tertiary, size: .sm))
            }
            StateTile(id: L("Map failed"), title: L("The map didn’t load."), message: L("Your plane is still flying. We’re showing the simple route until the map is back."), label: L("Map failed to load")) {
                MapFailedArt()
            } actions: {
                Button { } label: { HStack(spacing: 8) { MRIcon(.refresh, size: 14); Text(L("Reload map")) } }.buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
        }
    }

    // MARK: Loading

    private var loadingTiles: some View {
        LazyVGrid(columns: cols, spacing: 24) {
            loadingTile(L("Ticket"), label: L("Loading ticket")) {
                VStack(alignment: .leading, spacing: 10) {
                    Skeleton().frame(width: 150 * 0.6 - 8, height: 10)
                    HStack { Skeleton().frame(width: 42, height: 30); Spacer(); Skeleton().frame(width: 42, height: 30) }.padding(.top, 8)
                    Skeleton().frame(width: 150 * 0.8 - 22, height: 8).padding(.top, 6)
                    Skeleton().frame(width: 150 * 0.56 - 16, height: 8)
                    Skeleton().frame(width: 150 * 0.68 - 19, height: 8)
                    Spacer(minLength: 0)
                    Skeleton().frame(height: 34)
                }
                .padding(.horizontal, 14).padding(.vertical, 16)
                .frame(width: 150, height: 216)
                .background(p.fill1.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
                .frame(maxWidth: .infinity).padding(.top, 14)
            }
            loadingTile(L("Wallet list"), label: L("Loading wallet")) {
                VStack(spacing: 16) {
                    ForEach([(52.0, 34.0), (64, 40), (44, 30), (58, 36)], id: \.0) { r in
                        HStack(spacing: 12) {
                            Skeleton(radius: 12).frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 7) {
                                GeometryReader { g in Skeleton().frame(width: g.size.width * r.0 / 100, height: 10) }.frame(height: 10)
                                GeometryReader { g in Skeleton().frame(width: g.size.width * r.1 / 100, height: 8) }.frame(height: 8)
                            }
                            Skeleton().frame(width: 36, height: 10)
                        }
                    }
                }.padding(.top, 20)
            }
            loadingTile(L("Stats"), label: L("Loading stats")) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach([38.0, 62, 48, 80, 56, 70, 42], id: \.self) { h in
                            Skeleton(radius: 6).frame(maxWidth: .infinity).frame(height: 150 * h / 100)
                        }
                    }.frame(height: 150, alignment: .bottom).padding(.horizontal, 6).padding(.top, 22)
                    HStack(spacing: 10) { Skeleton().frame(width: 88, height: 10); Skeleton().frame(width: 52, height: 10) }.padding(.top, 16)
                }
            }
        }
    }

    private func loadingTile<C: View>(_ id: String, label: String, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(.horizontal, 26).padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: 292)
            .overlay(alignment: .topLeading) {
                Text(id).font(.mr(.mono, size: 10, weight: 600)).tracking(10 * 0.1).textCase(.uppercase).foregroundStyle(p.text3.color).padding(.leading, 14).padding(.top, 12)
            }
            .mrGlass(cornerRadius: 26, elevation: .e2)
            .accessibilityElement(children: .contain).accessibilityLabel(label)
    }

    // MARK: Resumed

    private var resumed: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                ResumeBannerView(banner: .init(kind: .afterQuit, titleKey: "flight.resumed.title", bodyKey: "flight.resumed.afterQuit.body", arguments: [.minutes(25)]),
                                 detail: L("Quit 09:14 · back 09:31 · 17 min flown · 25 min left"))
                ResumeBannerView(banner: .init(kind: .afterSleep, titleKey: "flight.resumed.title", bodyKey: "flight.resumed.afterSleep.body", arguments: [.minutes(35)]),
                                 detail: L("Mac slept 09:14 · woke 09:21 · 7 min flown · 35 min left"))
                ResumeBannerView(banner: .init(kind: .landedWhileAway, titleKey: "flight.landedWhileAway.title", bodyKey: "flight.landedWhileAway.body", arguments: [.text("Paris")]))
                Text(L("The third banner is new copy outside the copy deck. Please confirm it."))
                    .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text3.color).padding(.horizontal, 6)
            }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                Text(L("How it decides")).mrText(.eyebrow).foregroundStyle(p.text1.color)
                Text(L("On launch or wake, Meridian compares now with the last saved tick. The flight is a function of clock time, so nothing has to run in the background."))
                    .font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color)
                VStack(alignment: .leading, spacing: 8) {
                    rule(L("Time left"), L("Resume where the clock says. The banner shows how long you were away."))
                    rule(L("Paused"), L("A flight paused on a break stays paused. No banner."))
                    rule(L("Past landing"), L("Land it, count all the minutes, add the stamp, show the third banner."))
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .mrGlass(cornerRadius: 22, elevation: .e2)
        }
    }

    private func rule(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(k).font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.accent2.color).frame(width: 92, alignment: .leading).padding(.top, 2).fixedSize(horizontal: false, vertical: true)
            Text(v).font(.mr(.ui, size: 13, weight: 400)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Art

struct IconBox: View {
    let name: MRIconName
    let tint: Color
    @Environment(\.mrPalette) private var p
    init(_ name: MRIconName, tint: Color) { self.name = name; self.tint = tint }
    var body: some View {
        MRIcon(name, size: 24).foregroundStyle(tint).frame(width: 64, height: 64)
            .background(p.fill2.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
    }
}

private struct EmptyTicketArt: View {
    @Environment(\.mrPalette) private var p
    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                var t = Path()
                t.move(to: CGPoint(x: 22, y: 6)); t.addLine(to: CGPoint(x: 136, y: 6)); t.addArc(center: CGPoint(x: 136, y: 14), radius: 8, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                t.addLine(to: CGPoint(x: 144, y: 36)); t.addArc(center: CGPoint(x: 144, y: 45), radius: 9, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
                t.addLine(to: CGPoint(x: 144, y: 78)); t.addArc(center: CGPoint(x: 136, y: 78), radius: 8, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                t.addLine(to: CGPoint(x: 14, y: 86)); t.addArc(center: CGPoint(x: 14, y: 78), radius: 8, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
                t.addLine(to: CGPoint(x: 6, y: 54)); t.addArc(center: CGPoint(x: 6, y: 45), radius: 9, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
                t.addLine(to: CGPoint(x: 6, y: 14)); t.addArc(center: CGPoint(x: 14, y: 14), radius: 8, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                t.closeSubpath()
                ctx.stroke(t, with: .color(p.text3.color), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))
                var perf = Path(); perf.move(to: CGPoint(x: 104, y: 12)); perf.addLine(to: CGPoint(x: 104, y: 80))
                ctx.stroke(perf, with: .color(p.text3.color), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                ctx.fill(Path(roundedRect: CGRect(x: 24, y: 24, width: 44, height: 8), cornerRadius: 4), with: .color(p.fill3.color))
                ctx.fill(Path(roundedRect: CGRect(x: 24, y: 42, width: 62, height: 6), cornerRadius: 3), with: .color(p.fill2.color))
                ctx.fill(Path(roundedRect: CGRect(x: 24, y: 56, width: 34, height: 6), cornerRadius: 3), with: .color(p.fill2.color))
            }
            MRIcon(.plane, size: 24).foregroundStyle(p.text3.color).offset(x: 112, y: 34)
        }.frame(width: 150, height: 92)
    }
}

private struct EmptyFriendsArt: View {
    @Environment(\.mrPalette) private var p
    var body: some View {
        Canvas { ctx, _ in
            for (i, cx) in [40.0, 75, 110].enumerated() {
                let r = CGRect(x: cx - 26, y: 20, width: 52, height: 52)
                if i > 0 { ctx.fill(Path(ellipseIn: r), with: .color(p.bg2.color)) }
                ctx.stroke(Path(ellipseIn: r), with: .color(p.text3.color), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
            }
            var plus = Path(); plus.move(to: CGPoint(x: 110, y: 36)); plus.addLine(to: CGPoint(x: 110, y: 56)); plus.move(to: CGPoint(x: 100, y: 46)); plus.addLine(to: CGPoint(x: 120, y: 46))
            ctx.stroke(plus, with: .color(p.text2.color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }.frame(width: 150, height: 92)
    }
}

private struct EmptyCardArt: View {
    @Environment(\.mrPalette) private var p
    var body: some View {
        ZStack(alignment: .topLeading) {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            shape.fill(p.fill1.color).frame(width: 108, height: 74).offset(x: 21, y: 9)
            shape.stroke(p.text3.color, style: StrokeStyle(lineWidth: 2, dash: [5, 6])).frame(width: 108, height: 74).offset(x: 21, y: 9)
            Capsule().fill(p.fill3.color).frame(width: 40, height: 5).offset(x: 36, y: 61)
            MRIcon(.lock, size: 22).foregroundStyle(p.text2.color).offset(x: 97, y: 21)
        }.frame(width: 150, height: 92, alignment: .topLeading)
    }
}

private struct MapFailedArt: View {
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let sea = MRMapPalette.resolve(.terra, dark: scheme == .dark).sea.color
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(sea).frame(width: 166, height: 88).offset(x: 2, y: 2)
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1.5).frame(width: 166, height: 88).offset(x: 2, y: 2)
            Canvas { ctx, _ in
                var r = Path(); r.move(to: CGPoint(x: 26, y: 66)); r.addCurve(to: CGPoint(x: 144, y: 50), control1: CGPoint(x: 54, y: 28), control2: CGPoint(x: 112, y: 26))
                ctx.stroke(r, with: .color(p.accent1.color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [1, 7]))
                ctx.fill(Path(ellipseIn: CGRect(x: 21, y: 61, width: 10, height: 10)), with: .color(p.text1.color))
                ctx.fill(Path(ellipseIn: CGRect(x: 139, y: 45, width: 10, height: 10)), with: .color(p.text1.color))
            }
            MRIcon(.plane, size: 22).foregroundStyle(p.accent1.color).rotationEffect(.degrees(-8)).offset(x: 73, y: 26)
        }.frame(width: 170, height: 92, alignment: .topLeading)
    }
}
