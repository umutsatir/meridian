import AppKit
import MeridianCore
import MeridianData
import MeridianMaps
import MeridianUI
import SwiftUI

/// What the landing screen shows (`Landing.dc.html` props).
struct LandingInfo: Equatable {
    var origin: Airport
    var destination: Airport
    var minutes: Int
    var km: Int
    var streak: Int
    var touchdown: String
    var topic: String
    /// Kilometres to the next membership tier after this landing (the toast of "Add to wallet").
    var kmToGold: Int
    var notes = ""
    /// The printed ticket (landed).
    var pass: BoardingPassModel?

    static func demo() -> LandingInfo {
        LandingInfo(origin: PlanKit.index.airport(iata: "LHR")!, destination: PlanKit.index.airport(iata: "CDG")!,
                    minutes: 42, km: 348, streak: 6, touchdown: "10:42", topic: "Auth module refactor", kmToGold: 20000 - (12022 + 348), pass: .sample)
    }

    @MainActor
    init?(model: AppModel) {
        let flight: Flight
        var credited: Double, after: Double
        if let summary = model.latestLanding {
            flight = summary.flight; credited = summary.creditedKm; after = summary.totalKmAfter
        } else if let last = model.lastLanded {
            flight = last; credited = last.creditedKm; after = model.totalKm
        } else { return nil }
        guard let o = model.airport(flight.originIata), let d = model.airport(flight.destinationIata ?? flight.originIata) else { return nil }
        let f = flight
        origin = o; destination = d
        minutes = Int(((f.finalFocusedSec ?? f.elapsedSec(at: f.endedAt ?? .now)) / 60).rounded())
        km = Int(credited.rounded())
        streak = max(1, model.streak)
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        touchdown = df.string(from: f.endedAt ?? .now)
        topic = f.topic
        notes = f.notes
        kmToGold = Int(max(0, MembershipTier.meridianGold.thresholdKm - after))
        let name = NSFullUserName().isEmpty ? "You" : NSFullUserName()
        pass = WalletBuilder.tickets(from: [f], airport: { model.airport($0) }, passenger: name).first?.model
    }

    init(origin: Airport, destination: Airport, minutes: Int, km: Int, streak: Int, touchdown: String, topic: String, kmToGold: Int, pass: BoardingPassModel? = nil) {
        self.origin = origin; self.destination = destination; self.minutes = minutes; self.km = km; self.streak = streak
        self.touchdown = touchdown; self.topic = topic; self.kmToGold = kmToGold; self.pass = pass
    }
}

/// The landed boarding pass (310 x 389 at 0.86): `BoardingPassView` `.landed` with the green LANDED ink stamp.
/// `animates` plays the print-in (rise and settle) and the stamp: 60 ms thump (`MRSound.stamp`) then 120 ms bleed.
struct LandingTicketSlot: View {
    let info: LandingInfo
    var animates = false
    @State private var risen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pass: BoardingPassModel {
        if var m = info.pass { m.landTime = info.touchdown; return m }
        return BoardingPassModel(originCode: info.origin.iata, originCity: info.origin.shortCity,
                                 destinationCode: info.destination.iata, destinationCity: info.destination.shortCity,
                                 durationMinutes: info.minutes, distanceKm: info.km, topic: info.topic, landTime: info.touchdown)
    }

    var body: some View {
        let moves = animates && !reduceMotion
        BoardingPassView(pass, state: .landed, scale: 0.86)
            .paperLandedStampAnimation(animates) {
                MRSound.shared.play(.stamp)
                PaperHaptics.release()
            }
            .offset(y: moves && !risen ? 18 : 0)
            .opacity(moves && !risen ? 0 : 1)
            .onAppear { if moves { withAnimation(MRMotion.ease(MRMotion.d4)) { risen = true } } }
    }
}

/// S22: the landing summary. `onFlyAgain` continues from the destination, `onWallet` stores the notes and leaves.
struct LandingScreen: View {
    let info: LandingInfo
    var onFlyAgain: () -> Void = {}
    var onWallet: (String) -> Void = { _ in }
    var animates = false
    /// S23 artboard: a fixed point of the ticket-into-wallet flight (0...1) instead of the running animation.
    var fixedFly: Double?
    /// Draws the toast of the finished flight (artboard).
    var fixedAdded = false
    @State private var notes = ""
    @State private var added = false
    /// The notes field becomes focusable shortly after appearing so it never steals focus (and the focus ring) on appear.
    @State private var notesArmed = false
    @State private var fly: Double = 0
    @State private var flyTask: Task<Void, Never>?
    @FocusState private var notesFocused: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.shellSidebarInset) private var inset
    @Environment(\.shellTicketsFrame) private var ticketsFrame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var u: Double { fixedFly ?? fly }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                p.bg0.color
                EuropeMapView(style: .terra, center: info.destination.coordinate, zoom: 1.5, showsLabels: false)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .saturation(0.9)
                    .blur(radius: 12)
                    .scaleEffect(1.06)
                    .clipped()
                Color(.sRGB, red: 5 / 255, green: 7 / 255, blue: 13 / 255, opacity: 0.40)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(info.destination.shortName) · Touchdown \(info.touchdown)").mrEyebrow().frame(height: 14)
                    Text("Landed in \(info.destination.shortCity).")
                        .font(.mr(.serif, size: 52, weight: 500)).tracking(-0.78)
                        .foregroundStyle(p.text1.color).frame(height: 58, alignment: .leading).padding(.top, 6)
                }
                .offset(x: 272, y: 58)

                ticket

                column(p).offset(x: 690, y: 150)

                if (added && u >= 1) || fixedAdded {
                    MRToast("Added to your wallet", message: "+\(info.km) km. You're \(CruiseFrame.km(info.kmToGold)) km from Meridian Gold.")
                        .position(x: 748, y: geo.size.height - 30 - 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .animation(reduceMotion ? nil : MRMotion.smooth, value: added && u >= 1)
            .onAppear {
                if notes.isEmpty { notes = info.notes }
                model.landingFly = fixedFly ?? 0
                // the notes field must not grab focus on appear (canvas: no autofocus)
                Task { @MainActor in try? await Task.sleep(for: .milliseconds(500)); notesArmed = true }
            }
            .onDisappear { flyTask?.cancel(); model.landingFly = 0 }
            .onChange(of: model.landingAddRequests) { _, _ in add() }
        }
    }

    /// The ticket: at rest (272, 150); on "Add to wallet" it flies to the Tickets icon of the sidebar (`Landing.dc.html` `addWallet`):
    /// smoothstep over 900 ms, scale 1 to 0.1, rotation 0 to -6 degrees, fading out after 90 %.
    private var ticket: some View {
        let e = u * u * (3 - 2 * u)
        let target = ticketsFrame == .zero ? CGPoint(x: 38, y: 240) : CGPoint(x: ticketsFrame.minX + 19, y: ticketsFrame.midY)
        let rest = CGPoint(x: 272 + 155, y: 150 + 194.5)
        let cx = rest.x + (target.x - rest.x) * e, cy = rest.y + (target.y - rest.y) * e
        let opacity = u > 0.9 ? max(0, 1 - (u - 0.9) * 10) : 1
        return LandingTicketSlot(info: info, animates: animates)
            .scaleEffect(1 - 0.9 * e)
            .rotationEffect(.degrees(-6 * e))
            .opacity(opacity)
            .position(x: cx, y: cy)
            .allowsHitTesting(false)
            .zIndex(12)
    }

    private func column(_ p: MRPalette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    tile("Time focused", number: String(info.minutes), unit: "min", p: p)
                    tile("Distance", number: CruiseFrame.km(info.km), unit: "km", p: p)
                }
                GridRow {
                    tile("Miles earned", number: "+\(CruiseFrame.km(info.km))", unit: "km", p: p)
                    tile("Streak", number: String(info.streak), unit: info.streak == 1 ? "day" : "days", p: p, chevrons: true)
                }
            }
            notesCard(p).padding(.top, 16)
            HStack(spacing: 12) {
                Button { add() } label: { HStack(spacing: 8) { MRIcon(.wallet, size: 18); Text("Add to wallet") } }
                    .buttonStyle(MRButtonStyle(.primary, size: .lg)).disabled(added)
                Button { onFlyAgain() } label: { HStack(spacing: 8) { MRIcon(.plane, size: 18); Text("Fly again from \(info.destination.iata)") } }
                    .buttonStyle(MRButtonStyle(.secondary, size: .lg))
                Button {} label: { MRIcon(.share, size: 18) }
                    .buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Share card").help("Share card")
            }
            .padding(.top, 18)
        }
        .frame(width: 540, alignment: .leading)
    }

    private func tile(_ title: String, number: String, unit: String, p: MRPalette, chevrons: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).mrEyebrow().frame(height: 14)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(number).font(.mr(.serif, size: 40, weight: 500)).tracking(-0.4)
                Text(unit).font(.mr(.ui, size: 14, weight: 500)).foregroundStyle(p.text2.color).padding(.leading, chevrons ? 10 : 6)
                if chevrons {
                    Spacer()
                    Chevrons().stroke(p.accent2.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)).frame(width: 26, height: 22)
                }
            }
            .foregroundStyle(p.text1.color)
            .frame(height: 40)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 96)
        .cruiseGlass(20, .e2)
        .accessibilityElement(children: .combine)
    }

    private struct Chevrons: Shape {
        nonisolated func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 3, y: 18)); p.addLine(to: CGPoint(x: 13, y: 4)); p.addLine(to: CGPoint(x: 23, y: 18))
            p.move(to: CGPoint(x: 8, y: 18)); p.addLine(to: CGPoint(x: 13, y: 11)); p.addLine(to: CGPoint(x: 18, y: 18))
            return p
        }
    }

    private func notesCard(_ p: MRPalette) -> some View {
        let ink = p.ink.color
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Notes").font(.mr(.ui, size: 10, weight: 700)).tracking(1.8).textCase(.uppercase).foregroundStyle(cruiseRGBA(20, 17, 15, 0.64)).frame(height: 12)
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("What did you get done?").font(.mr(.serif, size: 22, italic: true)).foregroundStyle(cruiseRGBA(20, 17, 15, 0.38)).lineSpacing(8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Binding(get: { notes }, set: { notes = String($0.prefix(140)) }))
                    .font(.mr(.serif, size: 22, italic: true)).foregroundStyle(ink).scrollContentBackground(.hidden)
                    .scrollDisabled(true).focused($notesFocused).disabled(!notesArmed)
                    .padding(.horizontal, -5).padding(.vertical, -8)
                    .accessibilityLabel("What did you get done?")
            }
            .frame(height: 96, alignment: .topLeading)
            HStack {
                Text("Saved on the back of your ticket")
                Spacer()
                Text("\(notes.count) / 140")
            }
            .font(.mr(.mono, size: 11)).foregroundStyle(cruiseRGBA(20, 17, 15, 0.64)).padding(.top, 4)
        }
        .padding(.top, 18).padding(.horizontal, 22).padding(.bottom, 16)
        .background(shape.fill(p.paper.color))
        .overlay(shape.strokeBorder(p.accent1.color, lineWidth: notesFocused ? 2 : 0))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 18)
        .overlay(MRInsetShadow(shape, color: .white.opacity(0.7), y: 1))
    }

    /// Runs the 900 ms flight, then the thump, the toast and (900 ms later) the hand-over to the wallet.
    private func add() {
        guard !added else { return }
        added = true
        let notes = notes
        if reduceMotion {
            fly = 1; model.landingFly = 1
            finishFly(notes)
            return
        }
        flyTask = Task { @MainActor in
            let t0 = ContinuousClock.now
            while !Task.isCancelled {
                let t = (ContinuousClock.now - t0) / .milliseconds(900)
                let v = min(1, max(0, t))
                fly = v; model.landingFly = v
                if v >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard !Task.isCancelled else { return }
            finishFly(notes)
        }
    }

    private func finishFly(_ notes: String) {
        MRSound.shared.play(.thump)
        PaperHaptics.release()
        flyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            onWallet(notes)
        }
    }
}
