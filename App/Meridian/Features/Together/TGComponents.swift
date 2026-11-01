import MeridianUI
import SwiftUI

// Shared pieces of the Together screens (Together.dc.html: .tg-h .tg-ttl .tg-card .tg-row .tg-lbl .tg-opt .tg-step .tg-qr .tg-code).

/// Left edge of the content (sidebar 220 + 8 + 8 + 16 = 252 at full width), as the canvas.
struct TGLayout {
    var left: CGFloat
    var width: CGFloat
    var right: CGFloat { width - 32 }
    var contentWidth: CGFloat { right - left }
}

struct TGEyebrow: View {
    let text: String
    @Environment(\.mrPalette) private var p
    var body: some View { Text(text).mrText(.eyebrow).foregroundStyle(p.text2.color) }
}

struct TGTitle: View {
    let text: String
    var size: CGFloat = 44
    var line: CGFloat = 48
    @Environment(\.mrPalette) private var p
    var body: some View {
        Text(text).font(.mr(.serif, size: size, weight: 500)).tracking(-0.015 * size).foregroundStyle(p.text1.color)
            .frame(height: line, alignment: .leading).lineLimit(1).fixedSize()
    }
}

/// `.tg-h`: eyebrow + serif title, with an optional trailing view aligned to the baseline.
struct TGHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) { TGEyebrow(text: eyebrow).frame(height: 14); TGTitle(text: title) }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

struct TGLabel: View {
    let text: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        Text(text).font(.mr(.ui, size: 10, weight: 600)).tracking(0.14 * 10).textCase(.uppercase).foregroundStyle(p.text3.color)
            .frame(height: 12).padding(.bottom, 8)
    }
}

/// `.tg-opt`: 36 pt option chip.
struct TGOption: View {
    let text: String
    let on: Bool
    var action: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    @State private var hover = false
    var body: some View {
        let p = MRPalette.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: action) {
            Text(text).font(.mr(.ui, size: 13, weight: 500))
                .foregroundStyle(on || hover ? p.text1.color : p.text2.color)
                .padding(.horizontal, 14).frame(height: 36)
                .background {
                    if on {
                        shape.fill(LinearGradient(colors: scheme == .dark
                                                  ? [MRColorToken(106, 183, 255, 0.22).color, MRColorToken(139, 243, 216, 0.10).color]
                                                  : [MRColorToken(30, 107, 255, 0.12).color, MRColorToken(24, 199, 160, 0.08).color],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else { shape.fill(hover ? p.fill2.color : p.fill1.color) }
                }
                .overlay { if on { shape.strokeBorder(scheme == .dark ? MRColorToken(106, 183, 255, 0.4).color : MRColorToken(30, 107, 255, 0.3).color, lineWidth: 1) } else { shape.strokeBorder(p.strokeHair.color, lineWidth: 1) } }
        }
        .buttonStyle(.plain).onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// `.tg-step`: 36 pt stepper with a mono value.
struct TGStepper: View {
    let value: Int
    var dec: () -> Void
    var inc: () -> Void
    @Environment(\.mrPalette) private var p
    var body: some View {
        HStack(spacing: 0) {
            cell(.minus, "Fewer", dec)
            Text("\(value)").font(.mr(.mono, size: 15, weight: 500)).foregroundStyle(p.text1.color).frame(width: 48, height: 36)
                .overlay(alignment: .leading) { p.strokeHair.color.frame(width: 1) }
                .overlay(alignment: .trailing) { p.strokeHair.color.frame(width: 1) }
            cell(.plus, "More", inc)
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.fill1.color))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
    }
    private func cell(_ icon: MRIconName, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { MRIcon(icon, size: 14).foregroundStyle(p.text2.color).frame(width: 36, height: 36).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

/// `.tg-code`: mono chip with the invite link.
struct TGCode: View {
    let text: String
    @Environment(\.mrPalette) private var p
    var body: some View {
        Text(text).font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
            .padding(.horizontal, 12).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.fill2.color))
    }
}

/// `.tg-qr`: 116 pt white tile with a real QR code (CoreImage) of the invite link.
struct TGQRTile: View {
    let text: String
    var body: some View {
        let m = TGQR.matrix(text)
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MRColorToken("#F3F5FA").color)
            .frame(width: 116, height: 116)
            .overlay {
                Canvas { ctx, size in
                    guard let n = m.first?.count, n > 0 else { return }
                    let c = size.width / CGFloat(n)
                    var path = Path()
                    for (y, row) in m.enumerated() { for (x, on) in row.enumerated() where on {
                        path.addRect(CGRect(x: CGFloat(x) * c, y: CGFloat(y) * c, width: c + 0.3, height: c + 0.3))
                    } }
                    ctx.fill(path, with: .color(MRColorToken("#0B1020").color))
                }
                .frame(width: 98, height: 98)
            }
            .accessibilityLabel("QR code for the invite link")
    }
}

/// Glass card (`.glass.eN.tg-card`).
extension View {
    func tgCard(radius: CGFloat = 26, _ e: MRElevation = .e2) -> some View { mrGlass(cornerRadius: radius, elevation: e) }
}

/// Round `.stamp` (Stamp.dc.html, shape round) without the ink-noise filter.
struct TGRoundStamp: View {
    var country = "FRANCE", code = "CDG", date = "29 OCT 2026", kind = "TOGETHER"
    var inkHex = "#243F8F"
    var rotation = -7.0
    var size: CGFloat = 150

    var body: some View {
        let k = size / 160
        let ink = MRColorToken(inkHex).color
        ZStack {
            Circle().strokeBorder(ink, lineWidth: 3 * k).frame(width: 150 * k, height: 150 * k)
            Circle().stroke(ink, lineWidth: 1 * k).frame(width: 139 * k, height: 139 * k)
            Circle().stroke(ink, style: StrokeStyle(lineWidth: 3.5 * k, dash: [0.9 * k, (2 * .pi * 63.75 * k) / 72 - 0.9 * k])).frame(width: 127.5 * k, height: 127.5 * k)
            Circle().stroke(ink, lineWidth: 1.1 * k).frame(width: 121 * k, height: 121 * k)
            Circle().stroke(ink, lineWidth: 1.2 * k).frame(width: 80 * k, height: 80 * k)
            arc(country, r: 50.5, fs: 14.5, ls: 3, mono: false, bottom: false, k: k, ink: ink)
            arc(kind + " · MERIDIAN", r: 52, fs: 6.8, ls: 2.4, mono: true, bottom: true, k: k, ink: ink)
            Text(code).font(.mr(.condensed, size: 27 * k, weight: 700)).tracking(1.2 * k).foregroundStyle(ink).position(x: 80 * k, y: 81 * k)
            Text(date).font(.mr(.mono, size: 6 * k, weight: 600)).tracking(0.5 * k).foregroundStyle(ink).position(x: 80 * k, y: 98.5 * k)
            MRIcon(.plane, size: 18 * k).rotationEffect(.degrees(90)).foregroundStyle(ink).position(x: 80 * k, y: 64 * k)
        }
        .frame(width: 160 * k, height: 160 * k)
        .rotationEffect(.degrees(rotation))
        .opacity(0.94).blendMode(.multiply)
        .accessibilityElement(children: .ignore).accessibilityLabel("Shared stamp, \(country)")
    }

    private func arc(_ s: String, r: CGFloat, fs: CGFloat, ls: CGFloat, mono: Bool, bottom: Bool, k: CGFloat, ink: Color) -> some View {
        let chars = Array(s)
        let cw = fs * (mono ? 0.6 : 0.5) + ls
        let step = Double(cw / r)
        return ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, c in
                let off = (Double(i) - Double(chars.count - 1) / 2) * step
                let th = (bottom ? .pi / 2 - off : -.pi / 2 + off)
                let x = 80 + r * CGFloat(cos(th)), y = 80 + r * CGFloat(sin(th))
                Text(String(c)).font(.mr(mono ? .mono : .condensed, size: fs * k, weight: mono ? 600 : 700)).foregroundStyle(ink)
                    .rotationEffect(.radians(th + .pi / 2 + (bottom ? .pi : 0)))
                    .position(x: x * k, y: y * k)
            }
        }
    }
}

/// Debug-only badge: the in-memory service is not a server (PRD §11.1). Never compiled into release builds.
struct TGPreviewBadge: View {
    var body: some View {
        #if DEBUG
        if TogetherAvailability.isPreviewBackend, !ProcessInfo.processInfo.arguments.contains("--screen") {
            Text("PREVIEW · LOCAL DATA").font(.mr(.mono, size: 9, weight: 600)).tracking(0.8)
                .foregroundStyle(.white).padding(.horizontal, 6).frame(height: 16)
                .background(Capsule().fill(Color.red.opacity(0.75)))
                .allowsHitTesting(false)
        }
        #endif
    }
}
