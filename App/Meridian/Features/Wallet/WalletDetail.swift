import AppKit
import MeridianCore
import MeridianUI
import SwiftUI

// MARK: - Ticket detail (S31 front, S31B back)

/// `TicketDetail.dc.html`: the wallet blurred under a scrim, one 432 x 542 ticket with pointer tilt, flip (Space) to
/// the notes / route / stats side, previous / next, and the Flip / Edit / Share / Delete pills. The sidebar stays
/// above this overlay (it is drawn by the shell).
struct TicketDetailView: View {
    let tickets: [WalletTicket]
    @Binding var index: Int
    let total: Int
    let colorBy: PaperColorBy
    /// Left edge of the canvas' `.td-stage` (244 beside the full sidebar).
    let stageLeft: CGFloat
    let startBack: Bool
    /// Canvas `tilt`: the fixed hover pose of the static artboard.
    let staticTilt: Bool
    let live: Bool
    let onClose: () -> Void
    let onDelete: (WalletTicket) -> Void
    let onSaveNotes: (WalletTicket, String) -> Void

    @Environment(\.mrPalette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var back = false
    @State private var rx = 0.0
    @State private var ry = 0.0
    @State private var ang = 0.0
    @State private var flipping = false
    @State private var editing = false
    @State private var draft = ""
    @State private var localNotes: [String: String] = [:]
    @State private var confirmDelete = false
    @FocusState private var rootFocused: Bool
    @FocusState private var editorFocused: Bool

    private var ticket: WalletTicket { tickets[min(max(0, index), tickets.count - 1)] }

    private func notes(_ t: WalletTicket) -> String { localNotes[t.id] ?? t.notes }

    private var shownModel: BoardingPassModel {
        var m = ticket.model(colorBy: colorBy)
        m.notes = editing ? "" : notes(ticket)
        return m
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let stageW = W - stageLeft
            let cx = stageLeft + stageW / 2
            ZStack(alignment: .topLeading) {
                p.scrim.color.contentShape(Rectangle()).onTapGesture { finishEditing(); onClose() }

                Text("Ticket \(index + 1) of \(total) · \(ticket.dateText)").mrEyebrow()
                    .frame(width: stageW, height: 14).offset(x: stageLeft, y: 34).allowsHitTesting(false)

                card(H: H).frame(width: 432, height: 542).offset(x: cx - 216, y: 84)

                navButton(.chevL, label: "Previous ticket", enabled: tickets.count > 1) { step(-1) }.offset(x: stageLeft + 70, y: 310)
                navButton(.chevR, label: "Next ticket", enabled: tickets.count > 1) { step(1) }.offset(x: W - 70 - 44, y: 310)

                HStack(spacing: 10) {
                    DetailPill(icon: .refresh, title: back ? "Flip to front" : "Flip to notes", key: "Space") { flip() }
                    DetailPill(icon: editing ? .check : .pencil, title: editing ? "Done" : "Edit") { editing ? finishEditing() : beginEditing() }
                    DetailPill(icon: .share, title: "Share") { share() }
                    DetailPill(icon: .trash, title: "Delete", danger: true) { confirmDelete = true }
                }
                .frame(width: stageW).offset(x: stageLeft, y: H - 34 - 40)
            }
            .frame(width: W, height: H, alignment: .topLeading)
        }
        .focusable().focusEffectDisabled().focused($rootFocused)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .space, .return, .escape]) { press in handle(press) }
        .onAppear { back = startBack; rootFocused = true }
        .onChange(of: index) { finishEditing(); back = false; ang = 0 }
        .alert("Delete this ticket?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { onDelete(ticket) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The flight leaves your wallet. Cards and stamps you earned stay.")
        }
    }

    // MARK: Keys

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if editing {
            if press.key == .escape { finishEditing(); return .handled }
            return .ignored
        }
        switch press.key {
        case .leftArrow: step(-1); return .handled
        case .rightArrow: step(1); return .handled
        case .space, .return: flip(); return .handled
        case .escape: onClose(); return .handled
        default: return .ignored
        }
    }

    private func step(_ d: Int) {
        guard tickets.count > 1 else { return }
        index = (index + d + tickets.count) % tickets.count
    }

    // MARK: Card

    private func card(H: CGFloat) -> some View {
        let tilting = live && (rx != 0 || ry != 0)
        let pose = staticTilt || tilting
        let ex = live ? rx : (staticTilt ? -5 : 0), ey = live ? ry : (staticTilt ? 7 : 0)
        return ZStack(alignment: .topLeading) {
            BoardingPassView(shownModel, state: ticket.state, side: back ? .back : .front, scale: 1.2, hoverPose: pose)
            if back { backControls }
        }
        .frame(width: 432, height: 542, alignment: .topLeading)
        .modifier(ProjectedTilt(rx: reduceMotion ? 0 : ex, ry: reduceMotion ? 0 : ey + ang, size: CGSize(width: 432, height: 542),
                                vanishing: CGPoint(x: 216, y: H / 2 - 84)))
        .shadow(color: .black.opacity(0.45), radius: 25, y: 40)
        .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d2), value: rx)
        .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d2), value: ry)
        .overlay {
            if live && !editing {
                Color.clear.contentShape(Rectangle())
                    .onContinuousHover { phase in
                        guard !flipping else { return }
                        switch phase {
                        case .active(let pt): ry = ((pt.x / 432 - 0.5) * 14 * 100).rounded() / 100; rx = ((-(pt.y / 542 - 0.5)) * 12 * 100).rounded() / 100
                        case .ended: rx = 0; ry = 0
                        }
                    }
                    .onTapGesture { flip() }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: back ? .contain : .ignore)
        .accessibilityLabel("Ticket \(ticket.from) to \(ticket.to). Press to flip.")
        .accessibilityAction(named: back ? "Flip to front" : "Flip to notes") { flip() }
    }

    /// Live Edit / Share / Delete hit areas over the printed pills and the editable notes (pass space 360 x 452, scaled 1.2).
    private var backControls: some View {
        ZStack(alignment: .topLeading) {
            if editing {
                TextEditor(text: $draft)
                    .font(.mr(.serif, size: 19, weight: 500, italic: true)).lineSpacing(4.5)
                    .foregroundStyle(MRColorToken("#14110F").opacity(0.92)).scrollContentBackground(.hidden)
                    .scrollIndicators(.never).focused($editorFocused)
                    .frame(width: 316, height: 112).offset(x: 20, y: 250)
                    .accessibilityLabel("Notes")
            }
            hit("Edit notes", x: 24, w: 72) { editing ? finishEditing() : beginEditing() }
            hit("Share ticket", x: 104, w: 84) { share() }
            hit("Delete ticket", x: 246, w: 90) { confirmDelete = true }
        }
        .frame(width: 360, height: 452, alignment: .topLeading)
        .scaleEffect(1.2, anchor: .topLeading)
    }

    private func hit(_ label: String, x: CGFloat, w: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Color.clear.frame(width: w, height: 34).contentShape(Rectangle()) }
            .buttonStyle(.plain).offset(x: x, y: 404).accessibilityLabel(label)
    }

    // MARK: Flip (260 ms accelerate to edge-on, swap, 260 ms back)

    private func flip() {
        guard !flipping else { return }
        finishEditing()
        if reduceMotion { back.toggle(); return }
        flipping = true; rx = 0; ry = 0
        withAnimation(MRMotion.easeAccel(0.26)) { ang = 90 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { back.toggle(); ang = -90 }
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(MRMotion.ease(0.26)) { ang = 0 }
            try? await Task.sleep(for: .milliseconds(270))
            flipping = false
        }
    }

    // MARK: Notes

    private func beginEditing() {
        if !back { flip(); Task { @MainActor in try? await Task.sleep(for: .milliseconds(620)); startEditor() } } else { startEditor() }
    }

    private func startEditor() {
        draft = notes(ticket); editing = true
        Task { @MainActor in editorFocused = true }
    }

    private func finishEditing() {
        guard editing else { return }
        editing = false
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if text != notes(ticket) { localNotes[ticket.id] = text; onSaveNotes(ticket, text) }
        rootFocused = true
    }

    // MARK: Share (PNG through ImageRenderer)

    private func share() {
        finishEditing()
        guard let url = ShareCard.write(ticket: ticket, colorBy: colorBy, notes: notes(ticket)) else { return }
        guard let view = NSApp.keyWindow?.contentView else { NSWorkspace.shared.activateFileViewerSelecting([url]); return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: CGRect(x: view.bounds.midX, y: 60, width: 1, height: 1), of: view, preferredEdge: .minY)
    }

    // MARK: Pieces

    private func navButton(_ icon: MRIconName, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        DetailRound(icon: icon) { action() }
            .disabled(!enabled).opacity(enabled ? 1 : 0.38)
            .accessibilityLabel(label)
    }
}

// MARK: - 3D tilt with the canvas' `.td-stage{perspective:1600px}` (vanishing point = stage centre)

private struct ProjectedTilt: ViewModifier {
    var rx: Double, ry: Double
    var size: CGSize
    /// Perspective origin in the card's local space.
    var vanishing: CGPoint
    var perspective: CGFloat = 1600

    func body(content: Content) -> some View { content.projectionEffect(transform) }

    private var transform: ProjectionTransform {
        var persp = CATransform3DIdentity
        persp.m34 = -1 / perspective
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        var r = CATransform3DMakeRotation(CGFloat(ry * .pi / 180), 0, 1, 0)
        r = CATransform3DConcat(r, CATransform3DMakeRotation(CGFloat(rx * .pi / 180), 1, 0, 0))
        // rotate about the card centre, then project about the vanishing point
        var m = CATransform3DMakeTranslation(-c.x, -c.y, 0)
        m = CATransform3DConcat(m, r)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(c.x - vanishing.x, c.y - vanishing.y, 0))
        m = CATransform3DConcat(m, persp)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(vanishing.x, vanishing.y, 0))
        return ProjectionTransform(m)
    }
}

// MARK: - Glass controls (`.td-nav`, `.td-pill`)

private struct DetailRound: View {
    let icon: MRIconName
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    @GestureState private var pressed = false

    var body: some View {
        Button(action: action) {
            MRIcon(icon, size: 18).foregroundStyle(p.text1.color).frame(width: 44, height: 44)
                .mrGlass(in: Circle(), elevation: .e3)
                .mrGlassControlWash(Circle(), hovering: hovering && isEnabled, pressed: pressed, dark: scheme == .dark)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, s, _ in s = true })
    }
}

private struct DetailPill: View {
    let icon: MRIconName
    let title: String
    var key: String?
    var danger = false
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false
    @GestureState private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MRIcon(icon, size: 14)
                Text(title).font(.mr(.ui, size: 13, weight: 500))
                if let key { MRKbd(key) }
            }
            .foregroundStyle(danger ? p.danger.color : p.text1.color)
            .padding(.horizontal, 16).frame(height: 40)
            .mrGlass(in: Capsule(), elevation: .e2)
            .mrGlassControlWash(Capsule(), hovering: hovering, pressed: pressed, dark: scheme == .dark)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, s, _ in s = true })
    }
}

// MARK: - Share card (1080 x 1350 PNG)

/// The image the Share button exports: the printed pass on the app's night background. Rendered with `ImageRenderer`.
struct ShareCardView: View {
    let ticket: WalletTicket
    let colorBy: PaperColorBy
    let notes: String

    var body: some View {
        let pal = MRPalette.dark
        ZStack {
            pal.bg1.color
            WalletGlow().environment(\.colorScheme, .dark)
            VStack(spacing: 0) {
                Text("LANDED").font(.mr(.ui, size: 22, weight: 500)).tracking(22 * 0.08).foregroundStyle(pal.text2.color).padding(.top, 84)
                Text("\(ticket.model.originCity) to \(ticket.model.destinationCity)").font(.mr(.serif, size: 64, weight: 500)).tracking(-1.3)
                    .foregroundStyle(pal.text1.color).padding(.top, 14)
                BoardingPassView({ var m = ticket.model(colorBy: colorBy); m.notes = notes; return m }(), state: ticket.state, scale: 2)
                    .padding(.top, 64)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    MRIcon(.plane, size: 28)
                    Text("Meridian").font(.mr(.serif, size: 34, weight: 500))
                    Text("·").foregroundStyle(pal.text3.color)
                    Text("\(ticket.km) km · \(ticket.minutes) min").font(.mr(.mono, size: 24, weight: 500)).foregroundStyle(pal.text2.color)
                }
                .foregroundStyle(pal.text1.color).padding(.bottom, 72)
            }
        }
        .frame(width: 1080, height: 1350)
        .environment(\.colorScheme, .dark)
    }
}

enum ShareCard {
    /// Renders the card to `Meridian <from>-<to>.png` in the temporary directory and returns its URL.
    @MainActor static func write(ticket: WalletTicket, colorBy: PaperColorBy, notes: String) -> URL? {
        let renderer = ImageRenderer(content: ShareCardView(ticket: ticket, colorBy: colorBy, notes: notes))
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Meridian \(ticket.from)-\(ticket.to) \(ticket.flightNumber.replacingOccurrences(of: " ", with: "")).png")
        do { try png.write(to: url); return url } catch { return nil }
    }
}
