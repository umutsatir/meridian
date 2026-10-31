import MeridianUI
import SwiftUI

// MARK: - S42 Lobby

struct TGLobbyScreen: View {
    @Bindable var model: TogetherModel
    let lay: TGLayout
    @Environment(\.mrPalette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if model.frozenMs != nil {
            content(at: Date())
        } else {
            TimelineView(.animation) { ctx in content(at: ctx.date) }
        }
    }

    private func content(at date: Date) -> some View {
        let t = model.lobbyMs(at: date)
        let room = model.room
        let members = room?.members ?? []
        func arrived(_ m: TGMember) -> Bool { (room?.arrivedAt[m.id]).map { _ in true } ?? false }
        func torn(_ m: TGMember) -> Double {
            guard let at = room?.tearAt[m.id] else { return 0 }
            return reduceMotion ? (t >= at ? 1 : 0) : min(1, max(0, Double(t - at) / 650))
        }
        let tornN = members.filter { torn($0) >= 1 }.count
        let all = !members.isEmpty && tornN == members.count
        let lastArr = members.last { arrived($0) && $0.id != "me" }
        let gateSec = max(0, 252 - Int((Double(t) / 100).rounded()))
        let friends = members.dropFirst().map { SeatMapFriend(seat: $0.seat, initial: $0.initial, tintHex: $0.tintHex, name: $0.name, presence: arrived($0) ? .atGate : .idle) }
        let leftW = lay.contentWidth - 364 - 20
        let c = room?.config ?? model.config

        return ZStack(alignment: .topLeading) {
            TGHeader(eyebrow: "Shared flight · \(room?.flight ?? "MR 0142")", title: "\(c.from) to \(c.to), \(c.minutes) min") {
                MRPill(all ? "All aboard" : "Gate opens in " + String(format: "%02d:%02d", gateSec / 60, gateSec % 60), kind: all ? .ok : .accent, pulsingDot: true)
            }
            .frame(width: lay.contentWidth).offset(x: lay.left, y: 52)

            // seat map
            ZStack(alignment: .topLeading) {
                SeatMap(selectedSeat: "1A", zone: nil, friends: Array(friends))
                    .scaleEffect(0.7, anchor: .topLeading)
                    .frame(width: 560, height: 274, alignment: .topLeading)
                    .offset(x: 26, y: 36)
            }
            .frame(width: leftW, height: 352, alignment: .topLeading).clipped().tgCard().offset(x: lay.left, y: 128)

            // at the gate
            VStack(alignment: .leading, spacing: 10) {
                TGEyebrow(text: "At the gate").frame(height: 14)
                ForEach(members) { m in
                    let a = arrived(m), u = torn(m)
                    HStack(spacing: 12) {
                        SeatAvatar(initial: m.initial, tintHex: m.tintHex, presence: a ? .atGate : .idle, diameter: 32, dot: 10)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(m.name).font(.mr(.ui, size: 14, weight: 600)).foregroundStyle(p.text1.color).frame(height: 18)
                            Text("Seat \(m.seat)").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text3.color)
                        }
                        Spacer(minLength: 0)
                        MRPill(u >= 1 ? "Torn" : (a ? "Checked in" : "On the way"), kind: u >= 1 ? .ok : (a ? .accent : .neutral))
                    }
                    .frame(height: 48).opacity(a ? 1 : 0.5)
                }
                Spacer(minLength: 0)
                p.strokeHair.color.frame(height: 1)
                HStack(spacing: 10) {
                    MRIcon(.users, size: 16).foregroundStyle(p.accent1.color)
                    Text(all ? "Everyone is aboard. Take-off in a moment." : (lastArr.map { "\($0.name) is at the gate" } ?? "Waiting for friends…"))
                        .font(.mr(.ui, size: 13)).foregroundStyle(p.text1.color)
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 20)
            .frame(width: 364, height: 352, alignment: .topLeading).tgCard().offset(x: lay.left + leftW + 20, y: 128)

            // stubs
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 0) {
                    TGEyebrow(text: "Stubs").frame(height: 14)
                    Text("\(tornN) of \(members.count)").font(.mr(.serif, size: 34, weight: 500)).foregroundStyle(p.text1.color).frame(height: 38).padding(.top, 6)
                    Text("torn off in order").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 18)
                }.frame(width: 150, alignment: .leading)
                ForEach(members) { m in
                    VStack(spacing: 8) {
                        ticket(m, a: arrived(m), u: torn(m), c: c)
                        Text(m.id == "me" ? "You · \(m.seat)" : "\(m.name) · \(m.seat)").font(.mr(.mono, size: 11, weight: 500)).foregroundStyle(p.text2.color).frame(height: 14)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
            .frame(width: lay.contentWidth, height: 288, alignment: .leading).tgCard(radius: 26, .e1).offset(x: lay.left, y: 496)
        }
        .onExitCommand { model.leaveRoom() }
    }

    private func ticket(_ m: TGMember, a: Bool, u: Double, c: TGRoomConfig) -> some View {
        let tearing = u > 0
        let base = TGTicket(variant: tearing ? .torn : .printed, from: c.from, to: c.to, fromCity: c.fromCity, toCity: c.toCity,
                            minutes: c.minutes, km: c.km, seat: m.seat, name: m.fullName, scale: 0.4, flat: true)
        return ZStack(alignment: .topLeading) {
            base.opacity(a ? 1 : 0.35)
            if tearing {
                StubTearSlot(progress: u, size: CGSize(width: 144, height: 240)) {
                    TGTicketStub(scale: 0.4, t: TGTicket(from: c.from, to: c.to, fromCity: c.fromCity, toCity: c.toCity, minutes: c.minutes, km: c.km, seat: m.seat, name: m.fullName))
                }
            }
        }
        .frame(width: 144, height: 240, alignment: .topLeading)
    }
}

// MARK: - S44 Group landing

struct TGLandingScreen: View {
    @Bindable var model: TogetherModel
    let lay: TGLayout
    @Environment(\.mrPalette) private var p
    @State private var anim = false

    var body: some View {
        let members = model.room?.members ?? TGLandingScreen.defaultCrew
        let c = model.room?.config ?? model.config
        let rightX = lay.left + 338
        let rightW = lay.right - rightX
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                TGEyebrow(text: "Charles de Gaulle · Touchdown 10:42").frame(height: 14)
                TGTitle(text: "Landed together.", size: 52, line: 58)
            }.offset(x: lay.left, y: 58)

            TGTicket(variant: .printed, from: c.from, to: c.to, fromCity: c.fromCity, toCity: c.toCity, minutes: c.minutes, km: c.km,
                     scenarioLabel: "Coding", group: members.map(\.initial), scale: 0.86)
                .offset(x: lay.left, y: 158)

            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    stat("Collective", "2 h 48", "min")
                    stat("Distance", "1,392", "km")
                    stat("Aboard", "\(members.count)", "of \(members.count)")
                }
                HStack(spacing: 18) {
                    VStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.offset) { i, m in
                            HStack(spacing: 14) {
                                SeatAvatar(initial: m.initial, tintHex: m.tintHex, presence: .landed, diameter: 32, dot: 10)
                                Text(m.fullName.split(separator: " ").map { $0.prefix(1) + $0.dropFirst().lowercased() }.joined(separator: " "))
                                    .font(.mr(.ui, size: 14, weight: 600)).foregroundStyle(p.text1.color)
                                Spacer(minLength: 0)
                                Text("10:42").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
                                MRPill("Landed", kind: .ok)
                            }
                            .padding(.horizontal, 18).frame(height: 50)
                        }
                    }.frame(maxWidth: .infinity)
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(p.paper.color).frame(width: 170, height: 170)
                        .overlay { TGRoundStamp(size: 150).scaleEffect(anim || model.frozenProgress != nil || reduceStatic ? 1 : 1.45).opacity(anim || reduceStatic ? 1 : 0) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10).tgCard()
                HStack(spacing: 12) {
                    Button { model.go(.create) } label: { HStack(spacing: 8) { MRIcon(.users, size: 18); Text("Fly again together") } }
                        .buttonStyle(MRButtonStyle(.primary, size: .lg))
                    Button {} label: { HStack(spacing: 8) { MRIcon(.wallet, size: 18); Text("Add to wallet") } }
                        .buttonStyle(MRButtonStyle(.secondary, size: .lg))
                    Button {} label: { MRIcon(.share, size: 18) }.buttonStyle(MRRoundButtonStyle()).accessibilityLabel("Share")
                    Spacer(minLength: 0)
                }
            }
            .frame(width: rightW).offset(x: rightX, y: 158)
        }
        .onAppear { withAnimation(.spring(response: MRMotion.bouncyParams.response, dampingFraction: MRMotion.bouncyParams.damping).delay(0.2)) { anim = true } }
    }

    private var reduceStatic: Bool { TogetherModel.launch != nil }

    static let defaultCrew: [TGMember] = [
        TGMember(id: "me", name: "You", fullName: "ELIF KAYA", initial: "E", tintHex: "#7AA2FF", seat: "1A"),
        TGMember(id: "anna", name: "Anna", fullName: "ANNA SVENSSON", initial: "A", tintHex: "#FF8FB1", seat: "1C"),
        TGMember(id: "mert", name: "Mert", fullName: "MERT DEMIR", initial: "M", tintHex: "#7ADDB2", seat: "2A"),
        TGMember(id: "jo", name: "Jo", fullName: "JO PARK", initial: "J", tintHex: "#FFB86B", seat: "2C"),
    ]

    private func stat(_ k: String, _ v: String, _ u: String) -> some View {
        VStack(alignment: .leading) {
            TGEyebrow(text: k).frame(height: 14)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(v).font(.mr(.serif, size: 38, weight: 500)).foregroundStyle(p.text1.color)
                Text(u).font(.mr(.ui, size: 14, weight: 500)).foregroundStyle(p.text2.color)
            }.frame(height: 40, alignment: .leading)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .topLeading).tgCard(radius: 20)
    }
}

// MARK: - S45 Public flights board

struct TGBoardScreen: View {
    @Bindable var model: TogetherModel
    let lay: TGLayout
    @Environment(\.mrPalette) private var p
    private let chips: [(String, String, MRIconName, String)] = [("code", "Coding", .code, "#B49CFF"), ("study", "Study", .cap, "#7AA2FF"), ("read", "Read", .book, "#7ADDB2"), ("work", "Work", .briefcase, "#FFB86B"), ("create", "Create", .spark, "#FF8FB1")]

    var body: some View {
        let flights = model.service.publicFlights.filter { f in
            switch model.boardFilter { case 1: f.minutes <= 25; case 2: f.minutes > 25 && f.minutes <= 60; case 3: f.minutes > 60; default: true }
        }
        ZStack(alignment: .topLeading) {
            TGHeader(eyebrow: "Together · Public flights", title: "Departures") {
                MRSegmented(selection: $model.boardFilter, options: [.init(0, "Any time"), .init(1, "≤ 25 min"), .init(2, "25 to 60"), .init(3, "60+")])
            }.frame(width: lay.contentWidth).offset(x: lay.left, y: 52)

            HStack(spacing: 10) {
                ForEach(chips, id: \.0) { c in ScenarioChip(name: c.1, icon: c.2, colorHex: c.3, isSelected: model.boardScenario == c.0) { model.boardScenario = c.0 } }
            }.offset(x: lay.left, y: 132)

            VStack(spacing: 0) {
                ForEach(Array(flights.enumerated()), id: \.element.id) { i, f in
                    HStack(spacing: 18) {
                        MRSplitFlapBoard(f.id, size: .xs).scaleEffect(0.86, anchor: .leading).frame(width: 160 * 0.86 * 0.9, alignment: .leading)
                        MRSplitFlapBoard(f.route, size: .xs, tone: .white).scaleEffect(0.86, anchor: .leading)
                        Text("\(f.minutes) min\n\(f.aboard) aboard").font(.mr(.mono, size: 12, weight: 500)).lineSpacing(2).foregroundStyle(p.text2.color).frame(width: 128, alignment: .leading)
                        Spacer(minLength: 0)
                        MRSplitFlapBoard(status(f), length: 17, size: .xs).scaleEffect(0.86, anchor: .trailing)
                        Button("Join") { model.go(.create) }.buttonStyle(MRButtonStyle(.secondary, size: .sm)).padding(.leading, 4).disabled(f.status == .departed)
                    }
                    .frame(height: 58)
                    .overlay(alignment: .bottom) { if i < flights.count - 1 { Color.white.opacity(0.07).frame(height: 1) } }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(MRColorToken("#0B1020").color))
            .frame(width: lay.contentWidth).offset(x: lay.left, y: 184)

            HStack(spacing: 12) {
                MRIcon(.shield, size: 16)
                (Text("Public flights are quiet by design: no chat, no names, just company. Be kind; read the ") + Text("community guidelines").underline() + Text("."))
                    .font(.mr(.ui, size: 13))
            }
            .foregroundStyle(p.text2.color).frame(width: lay.contentWidth, alignment: .leading).offset(x: lay.left, y: 690)
        }
    }

    private func status(_ f: TGPublicFlight) -> String {
        switch f.status {
        case .boarding: "BOARDING"
        case .departed: "DEPARTED"
        case .boardingIn(let s): String(format: "BOARDING IN %02d:%02d", s / 60, s % 60)
        }
    }
}
