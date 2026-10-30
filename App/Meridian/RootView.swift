import MeridianCore
import MeridianUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = MRPalette.resolve(scheme)
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 220)
            Divider()
            Group {
                switch model.section {
                case .fly:
                    if model.activeFlight != nil { InFlightView() } else { PlanView() }
                case .wallet, .map, .stats, .together:
                    ComingSoonView(section: model.section)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.bg0.color)
        .ignoresSafeArea(.container, edges: .top)
        .task {
            while !Task.isCancelled {
                model.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            model.tick()
        }
    }
}

private struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = MRPalette.resolve(scheme)
        VStack(alignment: .leading, spacing: MRSpacing.xs) {
            Text(MRBrand.name)
                .mrText(.title2, .serif)
                .foregroundStyle(palette.text1.color)
                .padding(.top, 44)
                .padding(.horizontal, MRSpacing.s)
                .padding(.bottom, MRSpacing.s)

            if let flight = model.activeFlight {
                InFlightCapsule(flight: flight)
                    .padding(.bottom, MRSpacing.xs)
            }

            ForEach(AppSection.allCases) { section in
                Button { model.section = section } label: {
                    Label(section.title, systemImage: section.symbol)
                        .mrText(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, MRSpacing.xs)
                        .padding(.horizontal, MRSpacing.s)
                        .foregroundStyle(model.section == section ? palette.text1.color : palette.text2.color)
                        .background(
                            RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous)
                                .fill(model.section == section ? palette.bg2.color : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.section == section ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, MRSpacing.s)
        .padding(.bottom, MRSpacing.m)
        .background(palette.bg1.color)
    }
}

/// Remaining time, visible from every section (PRD §8).
private struct InFlightCapsule: View {
    let flight: Flight
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = MRPalette.resolve(scheme)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Image(systemName: "airplane")
                Text(flight.destinationIata ?? "Free flight").mrText(.callout)
                Spacer()
                Text(Clock.format(flight.remainingSec(at: context.date)) ?? "∞").mrText(.callout, .mono)
            }
            .padding(MRSpacing.s)
            .foregroundStyle(palette.onAccent.color)
            .background(palette.accent1.color, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("In flight to \(flight.destinationIata ?? "open skies"), \(Clock.spoken(flight.remainingSec(at: context.date))) remaining")
        }
    }
}

enum Clock {
    static func format(_ seconds: TimeInterval?) -> String? {
        guard let seconds else { return nil }
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func spoken(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "no end time" }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

private struct ComingSoonView: View {
    let section: AppSection
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = MRPalette.resolve(scheme)
        VStack(spacing: MRSpacing.s) {
            Image(systemName: section.symbol).font(.system(size: 40)).foregroundStyle(palette.text3.color)
            Text(section.title).mrText(.title1).foregroundStyle(palette.text1.color)
            Text(section == .together ? "Friends and shared flights arrive in v1.5." : "Your flights will show up here after your first landing.")
                .mrText(.body).foregroundStyle(palette.text2.color)
        }
    }
}
