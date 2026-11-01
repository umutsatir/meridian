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

    static func demo() -> LandingInfo {
        LandingInfo(origin: PlanKit.index.airport(iata: "LHR")!, destination: PlanKit.index.airport(iata: "CDG")!,
                    minutes: 42, km: 348, streak: 6, touchdown: "10:42", topic: "Auth module refactor", kmToGold: 20000 - 12370)
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
    }

    init(origin: Airport, destination: Airport, minutes: Int, km: Int, streak: Int, touchdown: String, topic: String, kmToGold: Int) {
        self.origin = origin; self.destination = destination; self.minutes = minutes; self.km = km; self.streak = streak
        self.touchdown = touchdown; self.topic = topic; self.kmToGold = kmToGold
    }
}

/// Call point of the landed boarding pass (ticket with the green LANDED ink stamp, built in another branch).
/// Replace the body with `TicketView(... state: .landed ...)` when it lands; the slot is 310 x 389 at (272, 150).
struct LandingTicketSlot: View {
    let info: LandingInfo
    var animates = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        VStack(alignment: .leading, spacing: 0) {
            Text("MERIDIAN AIR").font(.mr(.ui, size: 10, weight: 700)).tracking(1.4)
            Spacer()
            HStack(alignment: .lastTextBaseline) {
                Text(info.origin.iata).font(.mr(.condensed, size: 56, weight: 700))
                Spacer()
                Text(info.destination.iata).font(.mr(.condensed, size: 56, weight: 700))
            }
            Spacer()
            Text("\(info.topic)").font(.mr(.ui, size: 12))
        }
        .foregroundStyle(p.ink.color)
        .padding(20)
        .frame(width: 310, height: 389)
        .background(RoundedRectangle(cornerRadius: MRRadius.ticket, style: .continuous).fill(p.paper.color))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boarding pass \(info.origin.iata) to \(info.destination.iata), landed")
    }
}

/// S22: the landing summary. `onFlyAgain` continues from the destination, `onWallet` stores the notes and leaves.
struct LandingScreen: View {
    let info: LandingInfo
    var onFlyAgain: () -> Void = {}
    var onWallet: (String) -> Void = { _ in }
    var animates = false
    @State private var notes = ""
    @State private var added = false
    @FocusState private var notesFocused: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.shellSidebarInset) private var inset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    Text("\(info.destination.name.hasPrefix(info.destination.city + " ") ? String(info.destination.name.dropFirst(info.destination.city.count + 1)) : info.destination.name) · Touchdown \(info.touchdown)").mrEyebrow().frame(height: 14)
                    Text("Landed in \(info.destination.city).")
                        .font(.mr(.serif, size: 52, weight: 500)).tracking(-0.78)
                        .foregroundStyle(p.text1.color).frame(height: 58, alignment: .leading).padding(.top, 6)
                }
                .offset(x: 272, y: 58)

                LandingTicketSlot(info: info, animates: animates).offset(x: 272, y: 150)

                column(p).offset(x: 690, y: 150)

                if added {
                    MRToast("Added to your wallet", message: "+\(info.km) km. You're \(CruiseFrame.km(info.kmToGold)) km from Meridian Gold.")
                        .position(x: 748, y: geo.size.height - 30 - 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .animation(reduceMotion ? nil : MRMotion.smooth, value: added)
            .onAppear { if notes.isEmpty { notes = info.notes } }
        }
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
                    .scrollDisabled(true).focused($notesFocused)
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

    private func add() {
        guard !added else { return }
        added = true
        onWallet(notes)
    }
}
