import MeridianCore
import MeridianMaps
import MeridianUI
import SwiftUI

/// First-run onboarding (PRD §9.1, ONB-1…7): S01 welcome … S07 ready. The whole flow is drawn on the
/// design's 1280x800 canvas and scaled to fit the window; at 1280x800 it is 1:1.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @State private var model: OnboardingModel
    private let language: String?
    private let live: Bool
    private let onFinish: (OnboardingModel) -> Void

    /// `step`/`sub` select the artboard (debug routes); `live` turns the globe spin on.
    init(index: AirportIndex, step: Int = 1, sub: Int = 1, language: String? = nil, live: Bool = true,
         detected: DetectedPlace? = nil, onFinish: @escaping (OnboardingModel) -> Void = { _ in }) {
        _model = State(initialValue: OnboardingModel(index: index, step: step, sub: sub, detected: detected))
        self.language = language
        self.live = live
        self.onFinish = onFinish
    }

    var body: some View {
        let p = MRPalette.resolve(scheme)
        GeometryReader { geo in
            let s = min(geo.size.width / obCanvasWidth, geo.size.height / obCanvasHeight)
            ZStack {
                p.bg0.color
                canvas
                    .frame(width: obCanvasWidth, height: obCanvasHeight)
                    .clipped()
                    .scaleEffect(s)
                    .frame(width: obCanvasWidth * s, height: obCanvasHeight * s)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.locale, language.map { Locale(identifier: $0) } ?? Locale.current)
        .background {
            // Keyboard: ← → and Return move through the steps, Esc skips. (Hidden buttons rather than a
            // focusable root, so child controls do not all draw focus rings.)
            ZStack {
                Button("") { advance() }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { retreat() }.keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { advance() }.keyboardShortcut(.return, modifiers: [])
                Button("") { skip() }.keyboardShortcut(.escape, modifiers: [])
            }
            .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    // MARK: Navigation

    private func advance() {
        if model.step >= OnboardingModel.stepCount { onFinish(model) } else { model.go(model.step + 1) }
    }

    private func retreat() {
        if model.step == 5, model.sub > 1 { model.sub -= 1 } else if model.step > 1 { model.go(model.step - 1) }
    }

    private func skip() { model.go(OnboardingModel.stepCount) }

    // MARK: Canvas

    private var canvas: some View {
        let p = MRPalette.resolve(scheme)
        let step = model.step
        return ZStack(alignment: .topLeading) {
            p.bg0.color
            Group {
                switch step {
                case 1: OBWelcomeStep(live: live, onNext: advance, onSkip: skip)
                case 2: OBAirportStep(model: model)
                case 3: OBScenariosStep(model: model)
                case 4: OBMapStep(model: model)
                case 5: OBPermissionsStep(model: model, onAdvance: advancePermission)
                case 6: OBAccountStep(model: model, onNotNow: advance)
                default: OBReadyStep(model: model, onDone: { onFinish(model) })
                }
            }
            .id(step * 10 + (step == 5 ? model.sub : 0))
            .transition(.opacity)
            if (2...6).contains(step) { OBChrome(model: model, onBack: retreat, onNext: advance, onSkip: skip) }
        }
        .foregroundStyle(p.text1.color)
        .animation(MRMotion.ease(MRMotion.d3), value: step)
    }

    /// Permission warm-up CTAs: answer (or not) and go to the next ask; after the last one, the next step.
    private func advancePermission() {
        if model.sub < 3 { model.sub += 1 } else { model.go(6) }
    }
}

/// Chrome of steps 2-6: backdrop, step label, skip, back, progress dots, continue.
private struct OBChrome: View {
    let model: OnboardingModel
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            OBGlow(cx: 0.85, cy: 0, rx: 0.70, ry: 0.60, color: obRGBA(70, 92, 190, 0.22), stop: 0.70)
                .frame(width: obCanvasWidth, height: obCanvasHeight)
            OT("Step \(model.step) of \(OnboardingModel.stepCount)")
                .mrText(.eyebrow).foregroundStyle(p.text2.color)
                .obAt(96, 52)
            OBLink(title: "Skip setup", action: onSkip)
                .frame(width: 200, alignment: .trailing)
                .obAt(obCanvasWidth - 96 - 200, 44)
            footer(p)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
    }

    private func footer(_ p: MRPalette) -> some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 8) { MRIcon(.chevL, size: 18); OT("Back") }
            }
            .buttonStyle(MRButtonStyle(.secondary, pill: true))
            Spacer()
            Button(action: onNext) {
                HStack(spacing: 8) { OT("Continue"); MRIcon(.chevR, size: 18) }
            }
            .buttonStyle(MRButtonStyle(.primary, size: .lg))
            .disabled(model.step == 3 && model.selected.isEmpty)
        }
        .frame(width: obCanvasWidth - 192, height: 52)
        .overlay { dots(p) }
        .obAt(96, 704)
    }

    private func dots(_ p: MRPalette) -> some View {
        HStack(spacing: 8) {
            ForEach(1...OnboardingModel.stepCount, id: \.self) { i in
                Capsule()
                    .fill(i == model.step ? AnyShapeStyle(p.accentGradient) : AnyShapeStyle(i < model.step ? p.text3.color : p.fill3.color))
                    .frame(width: i == model.step ? 22 : 6, height: 6)
            }
        }
        .mrAnimation(MRMotion.snappy, value: model.step)
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(model.step) of \(OnboardingModel.stepCount)", tableName: "Onboarding"))
    }
}
