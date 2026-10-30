import SwiftUI

/// Every token-level component in both themes, for previews and screenshot checks (C12 UI kit).
public struct MRGallery: View {
    private let dark: Bool
    private let scrolls: Bool
    public init(dark: Bool = true, scrolls: Bool = true) { self.dark = dark; self.scrolls = scrolls }

    public var body: some View {
        let p = dark ? MRPalette.dark : MRPalette.light
        let content = VStack(alignment: .leading, spacing: 28) {
                typeSection(p)
                buttonSection(p)
                chipSection(p)
                controlSection(p)
                glassSection(p)
                iconSection(p)
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .leading)
        return Group { if scrolls { ScrollView { content } } else { content } }
        .background(p.bg1.color)
        .foregroundStyle(p.text1.color)
        .environment(\.colorScheme, dark ? .dark : .light)
        .preferredColorScheme(dark ? .dark : .light)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).mrEyebrow()
            content()
        }
    }

    private func typeSection(_ p: MRPalette) -> some View {
        section("Type") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Display 56").mrText(.display)
                Text("Title 1 · 34").mrText(.title1)
                Text("Title 2 · 24").mrText(.title2)
                Text("Headline 17").mrText(.headline)
                Text("Body 15 — Cleared for take-off").mrText(.body)
                Text("Callout 13").mrText(.callout).foregroundStyle(p.text2.color)
                Text("Caption 11").mrText(.caption).foregroundStyle(p.text2.color)
                HStack(spacing: 24) {
                    Text("CDG → AMS").mrText(.title2, .condensed)
                    Text("00:42:17").mrText(.title2, .mono)
                    Text("Ceremonial").mrText(.title2, .serif)
                    Text("Italic").font(.mr(.serif, size: 24, weight: 500, italic: true))
                }
            }
        }
    }

    private func buttonSection(_ p: MRPalette) -> some View {
        section("Buttons: default / hover / disabled") {
            HStack(spacing: 14) {
                Button { } label: { HStack(spacing: 8) { MRIcon(.plane, size: 16); Text("Check in") } }.buttonStyle(MRButtonStyle(.primary))
                Button("Hover") { }.buttonStyle(MRButtonStyle(.primary).hovering())
                Button("Disabled") { }.buttonStyle(MRButtonStyle(.primary)).disabled(true)
                Button("Secondary") { }.buttonStyle(MRButtonStyle(.secondary))
                Button("Hover") { }.buttonStyle(MRButtonStyle(.secondary).hovering())
                Button("Tertiary") { }.buttonStyle(MRButtonStyle(.tertiary))
                Button("Remove") { }.buttonStyle(MRButtonStyle(.danger))
            }
            HStack(spacing: 14) {
                Button("Large pill") { }.buttonStyle(MRButtonStyle(.primary, size: .lg, pill: true))
                Button("Small") { }.buttonStyle(MRButtonStyle(.secondary, size: .sm))
                Button { } label: { MRIcon(.sound, size: 18) }.buttonStyle(MRRoundButtonStyle())
                Button { } label: { MRIcon(.pause, size: 18) }.buttonStyle(MRRoundButtonStyle(on: true))
                Button { } label: { MRIcon(.settings, size: 16) }.buttonStyle(MRRoundButtonStyle(small: true))
            }
        }
    }

    private func chipSection(_ p: MRPalette) -> some View {
        section("Chip, tag, kbd, badge, avatar, pill") {
            HStack(spacing: 12) {
                ScenarioChip(name: "Study", icon: .book, colorHex: MRScenarioColor.study.hex, isSelected: true)
                ScenarioChip(name: "Work", icon: .briefcase, colorHex: MRScenarioColor.work.hex)
                ScenarioChip(name: "Code", icon: .code, colorHex: MRScenarioColor.code.hex).hoverPinned()
                ScenarioChip(name: "Meditate", icon: .lotus, colorHex: MRScenarioColor.meditate.hex, large: true)
            }
            HStack(spacing: 16) {
                AirportTag(code: "CDG", showsIcon: true)
                AirportTag(code: "AMS").hoverPinned()
                AirportTag(code: "BRU", isSelected: true)
                AirportTag(code: "FRA", isDisabled: true)
                AirportTag(code: "LHR", isDim: true, visitedColor: MRScenarioColor.code.color)
                MRKbd("⌘S"); MRKbd("F")
                MRBadge(3)
                MRAvatar("UM", presence: .online); MRAvatar("AB", tint: MRScenarioColor.create.color, size: .lg, presence: .left); MRAvatar("K", tint: MRScenarioColor.read.color, size: .sm)
            }
            HStack(spacing: 10) {
                MRPill("Neutral"); MRPill("On time", kind: .ok); MRPill("Delayed", kind: .warn); MRPill("Cancelled", kind: .danger)
                MRPill("Live", kind: .accent, pulsingDot: true); MRBoardingPill("Boarding")
                MRDot(pulsing: true).foregroundStyle(p.accent1.color)
            }
        }
    }

    private struct Controls: View {
        @State var seg = 1
        @State var on = true
        @State var off = false
        @State var v = 0.4
        @State var text = ""
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 24) {
                    MRSegmented(selection: $seg, options: [.init(0, "Day"), .init(1, "Week"), .init(2, "Month")])
                    Toggle("", isOn: $on).toggleStyle(MRToggleStyle()).labelsHidden()
                    Toggle("", isOn: $off).toggleStyle(MRToggleStyle()).labelsHidden()
                    MRSlider(value: $v).frame(width: 200)
                }
                HStack(spacing: 16) {
                    MRField("Search airports", text: $text, icon: .search).frame(width: 260)
                    MRProgressBar(0.6).frame(width: 160)
                    MRTooltip("Follow plane", key: "F")
                }
                MRDivider().frame(width: 400)
            }
        }
    }

    private func controlSection(_ p: MRPalette) -> some View {
        section("Segmented, toggle, slider, field, bar, tip, hr") { Controls() }
    }

    private func glassSection(_ p: MRPalette) -> some View {
        section("Glass e1 / e2 / e3, toast") {
            ZStack {
                MRMapPalette.resolve(.terra, dark: dark).sea.color
                HStack(spacing: 28) {
                    ForEach([MRElevation.e1, .e2, .e3], id: \.self) { e in
                        Text("\(String(describing: e))").mrText(.callout)
                            .frame(width: 120, height: 80)
                            .mrGlass(cornerRadius: MRRadius.card, elevation: e)
                    }
                    MRToast("Added to your wallet", message: "Boarding pass · CDG → AMS")
                }
                .padding(40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func iconSection(_ p: MRPalette) -> some View {
        section("Icons (24 grid, 1.5 stroke) at 20 pt") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(MRIconName.allCases, id: \.self) { n in
                    VStack(spacing: 6) {
                        MRIcon(n, size: 20)
                        Text(n.rawValue).mrText(.caption).textCase(nil).foregroundStyle(p.text3.color).lineLimit(1)
                    }
                    .frame(width: 84, height: 56)
                }
            }
        }
    }
}

extension MRElevation: Hashable {}

#Preview("Gallery · dark") { MRGallery(dark: true).frame(width: 1100, height: 1500) }
#Preview("Gallery · light") { MRGallery(dark: false).frame(width: 1100, height: 1500) }
