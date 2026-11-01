import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// S04: map style with live previews and the place-name toggle (ONB-4). Satellite belongs to Pro:
/// it previews, but picking it only shows a quiet hint.
struct OBMapStep: View {
    @Bindable var model: OnboardingModel
    @Environment(\.colorScheme) private var scheme
    @State private var proHint = false

    private struct Tile: Identifiable {
        let style: MapStyle
        let name: LocalizedStringKey
        let desc: LocalizedStringKey
        var id: MapStyle { style }
    }

    private static let tiles: [Tile] = [
        .init(style: .terra, name: "Terra", desc: "Day and night shading on a quiet globe"),
        .init(style: .mono, name: "Monochrome", desc: "Paper and ink. The calmest option"),
        .init(style: .standard, name: "Standard", desc: "Familiar coastlines and borders"),
        .init(style: .satellite, name: "Satellite", desc: "Terrain seen from above"),
    ]

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                OT("Choose your map.").obType(.serif, 48, 500, lh: 52, tracking: -0.02).foregroundStyle(p.text1.color)
                OT("Four ways to watch the flight. You can switch while flying.")
                    .obType(.ui, 17, 400, lh: 26).foregroundStyle(p.text2.color).padding(.top, 12)
            }
            .frame(width: 700, alignment: .leading)
            .obAt(96, 96)

            LazyVGrid(columns: [GridItem(.fixed(536), spacing: 16), GridItem(.fixed(536), spacing: 16)], spacing: 16) {
                ForEach(Self.tiles) { t in MapTile(tile: t, model: model, proHint: $proHint) }
            }
            .frame(width: 1088)
            .obAt(96, 226)

            HStack(spacing: 14) {
                MRIcon(.map, size: 20).foregroundStyle(p.text2.color)
                VStack(alignment: .leading, spacing: 0) {
                    OT("Place names").obType(.ui, 14, 600, lh: 18)
                    OT("Show city and sea names on the map").mrText(.callout).foregroundStyle(p.text2.color)
                }
                Spacer(minLength: 0)
                Toggle(isOn: $model.showsLabels) { EmptyView() }
                    .toggleStyle(MRToggleStyle())
                    .labelsHidden()
                    .accessibilityLabel(Text("Place names", tableName: "Onboarding"))
            }
            .padding(.horizontal, 20)
            .frame(width: 1088, height: 56)
            .mrGlass(cornerRadius: 18, elevation: .e1)
            .obAt(96, 628)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
    }

    private struct MapTile: View {
        let tile: Tile
        @Bindable var model: OnboardingModel
        @Binding var proHint: Bool
        @Environment(\.colorScheme) private var scheme
        @Environment(\.isFocused) private var focused
        @State private var hovered = false

        var body: some View {
            let p = MRPalette.resolve(scheme)
            let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
            let on = model.mapStyle == tile.style
            let locked = !MapStyleAccess.isUnlocked(tile.style)
            Button(action: pick) {
                ZStack(alignment: .topLeading) {
                    MapSurface(style: tile.style, center: Coordinate(latitude: 49.6, longitude: 3.5), zoom: 1.7,
                                  size: CGSize(width: 536, height: 132), showsLabels: model.showsLabels)
                        .frame(width: 536, height: 132).clipped()
                    route.frame(width: 536, height: 132)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                OT(tile.name).obType(.ui, 16, 600, lh: 20)
                                if locked { MRIcon(.lock, size: 12).foregroundStyle(p.text3.color) }
                            }
                            if locked && proHint && !on {
                                OT("Satellite is part of Meridian Pro.").mrText(.callout).foregroundStyle(p.text2.color)
                            } else {
                                OT(tile.desc).mrText(.callout).foregroundStyle(p.text2.color)
                            }
                        }
                        Spacer(minLength: 0)
                        if on {
                            HStack(spacing: 6) { MRIcon(.check, size: 12); OT("Selected").obType(.ui, 11, 600, lh: 11, tracking: 0.04).textCase(.uppercase) }
                                .foregroundStyle(p.accentPillText.color)
                                .padding(.horizontal, 10).frame(height: 24)
                                .background(p.isDark ? obRGBA(106, 183, 255, 0.16) : obRGBA(30, 107, 255, 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20).frame(width: 536)
                    .obAt(0, 142)
                }
                .frame(width: 536, height: 188, alignment: .topLeading)
                .background(p.bg2.color)
                .clipShape(shape)
                .overlay(shape.strokeBorder(on ? .clear : p.strokeHair.color, lineWidth: 1))
                .overlay { if on { shape.strokeBorder(p.accent1.color, lineWidth: 2).padding(-2) } }
                .shadow(color: on ? obRGBA(106, 183, 255, 0.28) : .clear, radius: 18)
                .offset(y: hovered ? -2 : 0)
                .mrFocusRing(focused, cornerRadius: 24, offset: 3, color: p.accent1.color)
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .onHover { hv in withAnimation(MRMotion.hover) { hovered = hv } }
            .animation(MRMotion.snappy, value: hovered)
            .animation(MRMotion.ease(MRMotion.d2), value: on)
            .accessibilityLabel(Text(tile.name, tableName: "Onboarding"))
            .accessibilityHint(locked ? Text("Part of Meridian Pro", tableName: "Onboarding") : Text(tile.desc, tableName: "Onboarding"))
            .accessibilityAddTraits(on ? [.isSelected] : [])
        }

        private func pick() {
            if !MapStyleAccess.isUnlocked(tile.style) {
                proHint = true   // quiet hint, no purchase prompt here
            } else {
                proHint = false
                model.mapStyle = tile.style
            }
        }

        private var route: some View {
            ZStack {
                Path { q in
                    q.move(to: CGPoint(x: 190, y: 100))
                    q.addQuadCurve(to: CGPoint(x: 400, y: 46), control: CGPoint(x: 300, y: 14))
                }
                .stroke(MRColorToken.hex("#6AB7FF"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                dot(CGPoint(x: 190, y: 100), fill: .white)
                dot(CGPoint(x: 400, y: 46), fill: MRColorToken.hex("#FFB547"))
            }
            .allowsHitTesting(false)
        }

        private func dot(_ c: CGPoint, fill: Color) -> some View {
            Circle().fill(fill).frame(width: 9, height: 9)
                .overlay(Circle().stroke(MRColorToken.hex("#06080D"), lineWidth: 2))
                .position(c)
        }
    }
}
