import MeridianCore
import MeridianUI
import SwiftUI

/// Placeholder cruise screen: the real map, window and HUD come next (PRD §9.4).
struct InFlightView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = MRPalette.resolve(scheme)
        if let flight = model.activeFlight {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: MRSpacing.m) {
                    Text("\(flight.originIata) → \(flight.destinationIata ?? "Free flight")")
                        .mrText(.title2).foregroundStyle(palette.text2.color)
                    Text(Clock.format(flight.remainingSec(at: context.date)) ?? "∞")
                        .mrText(.display, .mono).foregroundStyle(palette.text1.color)
                    if let progress = flight.progress(at: context.date) {
                        ProgressView(value: progress).tint(palette.accent1.color).frame(width: 360)
                    }
                    if flight.policy.allowsEarlyLanding || flight.isFreeFlight {
                        Button("Land early") { model.landEarly() }
                            .buttonStyle(MRButtonStyle(.secondary))
                    }
                }
            }
        }
    }
}
