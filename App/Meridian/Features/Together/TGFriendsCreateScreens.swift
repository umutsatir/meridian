import MeridianUI
import SwiftUI

// MARK: - S40 Friends

struct TGFriendsScreen: View {
    @Bindable var model: TogetherModel
    let lay: TGLayout
    @Environment(\.mrPalette) private var p

    var body: some View {
        let rightW: CGFloat = 368
        let leftW = lay.contentWidth - rightW - 28
        ZStack(alignment: .topLeading) {
            TGHeader(eyebrow: "Together", title: "Friends") {
                Button { model.addTab = .username } label: { HStack(spacing: 8) { MRIcon(.plus, size: 16); Text("Add friend") } }
                    .buttonStyle(MRButtonStyle(.primary))
            }
            .frame(width: lay.contentWidth).offset(x: lay.left, y: 52)

            list.frame(width: leftW).tgCard().offset(x: lay.left, y: 140)
            addCard.frame(width: rightW).tgCard().offset(x: lay.left + leftW + 28, y: 140)
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("On Meridian · \(model.friends.count)").mrText(.eyebrow).foregroundStyle(p.text2.color).padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 6)
            ForEach(model.friends) { f in TGFriendRow(friend: f, model: model) }
            p.strokeHair.color.frame(height: 1).padding(.horizontal, 18).padding(.vertical, 10)
            Text("Requests · \(model.requests.count)").mrText(.eyebrow).foregroundStyle(p.text2.color).padding(.horizontal, 18).padding(.vertical, 6)
            ForEach(model.requests) { r in
                HStack(spacing: 14) {
                    SeatAvatar(initial: r.initial, tintHex: r.tintHex, presence: .idle, diameter: 32, dot: 0).opacity(1)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(r.name).font(.mr(.ui, size: 14, weight: 600)).foregroundStyle(p.text1.color).frame(height: 18)
                        Text(r.hint).font(.mr(.ui, size: 13)).foregroundStyle(p.text3.color).frame(height: 18)
                    }
                    Spacer(minLength: 0)
                    Button("Decline") { model.decline(r) }.buttonStyle(MRButtonStyle(.secondary, size: .sm))
                    Button("Accept") { model.accept(r) }.buttonStyle(MRButtonStyle(.primary, size: .sm))
                }
                .padding(.horizontal, 18).frame(height: 64)
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 16)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a friend").font(.mr(.ui, size: 17, weight: 600)).foregroundStyle(p.text1.color).frame(height: 22)
            MRSegmented(selection: $model.addTab, options: [.init(.username, "Username"), .init(.link, "Invite link"), .init(.qr, "QR code")])
                .frame(maxWidth: .infinity)
            MRField("@username", text: $model.username, icon: .search).frame(height: 44)
                .onSubmit { model.sendRequest() }
            HStack(spacing: 14) {
                TGQRTile(text: "https://meridian.fly/elif-k")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Show this code or share your link. It works for 24 hours.").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color)
                        .fixedSize(horizontal: false, vertical: true)
                    TGCode(text: "meridian.fly/elif-k")
                }
            }
            Button {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString("https://meridian.fly/elif-k", forType: .string)
                model.notice = "Link copied."
            } label: { HStack(spacing: 8) { MRIcon(.copy, size: 16); Text("Copy invite link") }.frame(maxWidth: .infinity) }
                .buttonStyle(MRButtonStyle(.secondary))
            p.strokeHair.color.frame(height: 1)
            HStack(alignment: .top, spacing: 12) {
                MRIcon(.eye, size: 20).foregroundStyle(p.accent1.color).padding(.top, 1)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Privacy").font(.mr(.ui, size: 13, weight: 600)).foregroundStyle(p.text1.color).frame(height: 18)
                    Text("Friends see your flight status, never your task or location.").font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 22)
    }
}

struct TGFriendRow: View {
    let friend: TGFriend
    @Bindable var model: TogetherModel
    @Environment(\.mrPalette) private var p
    @State private var hover = false

    var body: some View {
        let hot = hover || model.hoveredFriend == friend.id
        HStack(spacing: 14) {
            SeatAvatar(initial: friend.initial, tintHex: friend.tintHex, presence: friend.presence, diameter: 44, dot: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(friend.name).font(.mr(.ui, size: 15, weight: 600)).foregroundStyle(p.text1.color).frame(height: 20)
                Text(friend.status).font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color).frame(height: 18).lineLimit(1)
            }
            Spacer(minLength: 0)
            if friend.canJoin {
                Button { model.go(.create) } label: { HStack(spacing: 6) { MRIcon(.seat, size: 14); Text("Join seat") } }
                    .buttonStyle(MRButtonStyle(.secondary, size: .sm))
            }
            if !friend.trailing.isEmpty { Text(friend.trailing).font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text3.color) }
            if hover {
                Menu {
                    Button("Report…") { model.reportTarget = friend }
                    Button("Block…", role: .destructive) { model.blockTarget = friend }
                } label: { MRIcon(.more, size: 16).foregroundStyle(p.text2.color).frame(width: 28, height: 28) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("More for \(friend.name)")
            }
        }
        .padding(.horizontal, 18).frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(hot ? p.fill1.color : .clear))
        .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
        .contextMenu {
            Button("Report…") { model.reportTarget = friend }
            Button("Block…", role: .destructive) { model.blockTarget = friend }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.name), \(friend.status)")
    }
}

// MARK: - S41 Create shared flight

struct TGCreateScreen: View {
    @Bindable var model: TogetherModel
    let lay: TGLayout
    @Environment(\.mrPalette) private var p
    private let cols = ["#7AA2FF", "#FF8FB1", "#7ADDB2", "#FFB86B", "#B49CFF", "#8BF3D8", "#FF9A9A", "#FFE9A8"]
    private let ini = ["E", "A", "M", "J", "S", "D", "K", "T"]

    var body: some View {
        let rightW: CGFloat = 388
        let leftW = lay.contentWidth - rightW - 28
        ZStack(alignment: .topLeading) {
            TGHeader(eyebrow: "Together", title: "Create a shared flight") { EmptyView() }
                .frame(width: lay.contentWidth).offset(x: lay.left, y: 52)
            form.frame(width: leftW).tgCard().offset(x: lay.left, y: 140)
            invite.frame(width: rightW).tgCard(radius: 26, .e3).offset(x: lay.left + leftW + 28, y: 140)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                TGLabel(text: "Route")
                HStack(spacing: 10) {
                    routeBtn(model.config.from, model.config.fromCity)
                    MRIcon(.route, size: 16).foregroundStyle(p.text1.color).frame(width: 32, height: 32).mrGlass(in: Circle(), elevation: .e1)
                    routeBtn(model.config.to, model.config.toCity)
                    Spacer(minLength: 0)
                    Text("\(model.config.minutes) min · \(model.config.km) km").font(.mr(.mono, size: 13, weight: 500)).foregroundStyle(p.text2.color)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                TGLabel(text: "Flight time")
                HStack(spacing: 8) {
                    ForEach([25, 42, 60, 90], id: \.self) { m in TGOption(text: "\(m) min", on: model.config.minutes == m) { model.config.minutes = m } }
                    TGOption(text: "Custom", on: false)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                TGLabel(text: "Gate opens in")
                HStack(spacing: 8) { ForEach([5, 10, 15, 30], id: \.self) { g in TGOption(text: "\(g) min", on: model.config.gateMinutes == g) { model.config.gateMinutes = g } } }
            }
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 0) {
                    TGLabel(text: "Group size · max \(model.maxGroup)")
                    HStack(spacing: 14) {
                        TGStepper(value: model.config.size, dec: { model.config.size = max(2, model.config.size - 1) }, inc: { model.config.size = min(model.maxGroup, model.config.size + 1) })
                        HStack(spacing: -6) {
                            ForEach(0..<8, id: \.self) { i in slot(i) }
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                Toggle("Public flight", isOn: $model.config.isPublic).toggleStyle(MRToggleStyle()).labelsHidden()
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.config.isPublic ? "Public flight" : "Private flight").font(.mr(.ui, size: 14, weight: 600)).foregroundStyle(p.text1.color).frame(height: 18)
                    Text(model.config.isPublic ? "Shown on the departures board. Anyone can ask to join." : "Only people with the link can join.")
                        .font(.mr(.ui, size: 13)).foregroundStyle(p.text2.color)
                }
            }
            if let e = model.createError { Text(e).font(.mr(.ui, size: 13)).foregroundStyle(p.dangerLabel.color) }
            HStack(spacing: 12) {
                Button("Create shared flight") { model.create() }.buttonStyle(MRButtonStyle(.primary, size: .lg))
                Button("Cancel") { model.go(.friends) }.buttonStyle(MRButtonStyle(.secondary, size: .lg))
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 26)
    }

    private func routeBtn(_ code: String, _ city: String) -> some View {
        HStack(spacing: 8) { AirportTag(code: code); Text(city) }.buttonLike()
    }

    @ViewBuilder private func slot(_ i: Int) -> some View {
        if i < model.config.size {
            SeatAvatar(initial: ini[i], tintHex: cols[i], presence: .idle, diameter: 22, dot: 0)
                .overlay(Circle().strokeBorder(p.bg1.color, lineWidth: 2).padding(-2))
        } else {
            Circle().fill(p.fill2.color).frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(p.strokeHair.color, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                .overlay(Circle().strokeBorder(p.bg1.color, lineWidth: 2).padding(-2))
        }
    }

    private var invite: some View {
        let c = model.config
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    TGEyebrow(text: "Invite card").frame(height: 14)
                    HStack(spacing: 8) {
                        Text(c.from).font(.mr(.condensed, size: 40, weight: 700)).tracking(0.4)
                        Text("→").font(.mr(.condensed, size: 40, weight: 700)).opacity(0.5)
                        Text(c.to).font(.mr(.condensed, size: 40, weight: 700)).tracking(0.4)
                    }.foregroundStyle(p.text1.color).frame(height: 44).padding(.top, 6)
                    Text("MR 0142 · \(c.minutes) min · \(c.km) km").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color).padding(.top, 4)
                }
                Spacer(minLength: 0)
                TGQRTile(text: "https://meridian.fly/MR0142-x7q")
            }
            HStack(spacing: 10) {
                TGCode(text: "meridian.fly/MR0142-x7q")
                Button {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString("https://meridian.fly/MR0142-x7q", forType: .string)
                } label: { HStack(spacing: 6) { MRIcon(.copy, size: 14); Text("Copy link") } }
                    .buttonStyle(MRButtonStyle(.primary, size: .sm))
            }
            HStack(spacing: 10) {
                MRPill("Gate opens in \(c.gateMinutes) min", kind: .accent, pulsingDot: true)
                Text("\(c.size) seats · \(c.isPublic ? "public" : "private")").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 24)
    }
}

private extension View {
    /// `.btn.btn-secondary` at 48 pt for the route pickers (non-interactive here: the airport picker is the Plan screen's).
    func buttonLike() -> some View { modifier(RouteButtonLook()) }
}

private struct RouteButtonLook: ViewModifier {
    @Environment(\.mrPalette) private var p
    func body(content: Content) -> some View {
        content
            .font(.mr(.ui, size: 15, weight: 600)).foregroundStyle(p.text1.color)
            .padding(.horizontal, 20).frame(height: 48)
            .background(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous).fill(p.fill2.color))
            .overlay(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
    }
}
