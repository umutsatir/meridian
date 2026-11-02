import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// Follow camera controls that sit under the zoom capsule: Recenter (when the camera is free), the orientation toggle
/// (North up / Heading up, shown while following and the pointer is over the map controls) and the logarithmic zoom
/// slider (the canvas' `zoomStyle` pill) which covers the whole zoom range.
struct CruiseFollowControls: View {
    @Bindable var ui: CruiseUI
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sliderHover = false

    private var showsOrientation: Bool { ui.camera.following && (ui.controlsHover || ui.camera.orientation == .headingUp) }
    private var showsSlider: Bool { (ui.controlsHover || ui.zoomHover || sliderHover || ui.camera.scale != nil) && ui.menu == nil }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if !ui.camera.following {
                CruiseCircleButton(icon: .target, label: "Recenter", kbd: "F", a11y: "Recenter on the plane", on: false) {
                    withAnimation(reduceMotion ? nil : MRMotion.ease(MRMotion.d3)) { ui.toggleFollow() }
                }
                .padding(.trailing, 24).padding(.top, 302)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else if showsOrientation {
                let up = ui.camera.orientation == .headingUp
                CruiseCircleButton(icon: .navigate, label: up ? "Heading up" : "North up", kbd: "⌥F",
                                   a11y: up ? "Heading up. Switch to north up" : "North up. Switch to heading up", on: up) {
                    ui.camera.toggleOrientation()
                }
                .padding(.trailing, 24).padding(.top, 302)
                .transition(.opacity)
            }
            CruiseZoomSlider(ui: ui)
                .padding(.trailing, 76).padding(.top, 202)
                .opacity(showsSlider ? 1 : 0)
                .allowsHitTesting(showsSlider)
                .onHover { sliderHover = $0 }
                .animation(MRMotion.ease(MRMotion.d2), value: showsSlider)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(reduceMotion ? nil : MRMotion.ease(MRMotion.d2), value: ui.camera.following)
        .animation(MRMotion.ease(MRMotion.d2), value: showsOrientation)
    }
}

/// Glass round button (40 pt) with a tooltip to its left.
struct CruiseCircleButton: View {
    let icon: MRIconName
    let label: String
    var kbd: String?
    let a11y: String
    var on = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) { MRIcon(icon, size: 18) }
            .buttonStyle(MRRoundButtonStyle(on: on))
            .accessibilityLabel(a11y)
            .onHover { hv in withAnimation(MRMotion.hover) { hover = hv } }
            .overlay(alignment: .trailing) {
                CruiseTip(text: label, kbd: kbd).offset(x: -(40 + 10)).opacity(hover ? 1 : 0)
                    .animation(MRMotion.ease(MRMotion.d2), value: hover).allowsHitTesting(false)
            }
    }
}

/// The canvas' vertical zoom pill: 40 x 150, accent fill from the bottom, white knob.
struct CruiseZoomSlider: View {
    @Bindable var ui: CruiseUI
    @Environment(\.colorScheme) private var scheme
    private let height: CGFloat = 150, pad: CGFloat = 12

    var body: some View {
        let p = MRPalette.resolve(scheme)
        let k = ui.zoomK
        let track = height - 2 * pad
        ZStack(alignment: .bottom) {
            Capsule().fill(p.fill2.color).frame(width: 4, height: track)
            Capsule().fill(p.accentGradient).frame(width: 4, height: max(4, track * k))
            Circle().fill(.white).frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1)
                .offset(y: 8 - track * k)
                .frame(height: track, alignment: .bottom)
        }
        .frame(width: 40, height: height)
        .cruiseGlass(20, .e2)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            ui.zoomK = 1 - Double((v.location.y - pad) / track)
        })
        .accessibilityElement()
        .accessibilityLabel("Zoom")
        .accessibilityValue("\(Int((k * 100).rounded())) percent")
        .accessibilityAdjustableAction { dir in ui.zoomStep(dir == .increment ? 1 : -1) }
    }
}
