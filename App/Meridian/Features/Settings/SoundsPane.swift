import MeridianUI
import Observation
import SwiftUI

// MARK: - Engine bridge

/// Connects the Sounds panel and the flight lifecycle to the real engine (`MRSound`).
@MainActor
enum CabinSound {
    /// A flight started or ended. Pushes the stored mixer to the engine first, so the bed fades in with the user's levels.
    static func flightChanged(active: Bool) {
        if active { MixerModel.shared.pushToEngine() }
        MRSound.shared.setFlightActive(active)
    }
}

// MARK: - Model

struct MixerLayer: Identifiable {
    let id: String
    let name: String
    static let all: [MixerLayer] = [
        .init(id: "hum", name: L("Cabin hum")), .init(id: "rain", name: L("Rain")), .init(id: "ocean", name: L("Ocean")),
        .init(id: "forest", name: L("Forest")), .init(id: "brown", name: L("Brown noise")), .init(id: "pink", name: L("Pink noise")),
        .init(id: "music", name: L("Soft music")),
    ]
}

struct MixerPreset: Identifiable {
    let id: String
    let name: String
    let colorHex: String
    let levels: [String: Int]
    let master: Int
    static let all: [MixerPreset] = [
        .init(id: "deep", name: L("Deep Work"), colorHex: "#B49CFF", levels: ["hum": 55, "brown": 38], master: 72),
        .init(id: "night", name: L("Night Flight"), colorHex: "#7AA2FF", levels: ["hum": 70, "brown": 22, "music": 34], master: 60),
        .init(id: "rainy", name: L("Rainy Read"), colorHex: "#7ADDB2", levels: ["hum": 30, "rain": 64, "music": 42], master: 68),
    ]
}

@MainActor
@Observable
final class MixerModel {
    static let shared = MixerModel()
    var levels: [String: Int] { didSet { persist() } }
    var muted: Set<String> { didSet { persist() } }
    var master: Int { didSet { persist() } }
    var preset: String?

    private init() {
        let d = UserDefaults.standard
        let p = MixerPreset.all.first { $0.id == SettingsKeys.soundPreset.current } ?? MixerPreset.all[0]
        levels = SettingsKeys.soundLevelsJSON.current.data(using: .utf8).flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? p.levels
        muted = SettingsKeys.soundMutedJSON.current.data(using: .utf8).flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) } ?? []
        master = d.object(forKey: SettingsKeys.soundMaster.name) as? Int ?? p.master
        preset = d.string(forKey: SettingsKeys.soundPreset.name) ?? p.id
    }

    func level(_ id: String) -> Int { levels[id] ?? 0 }

    func apply(_ p: MixerPreset) {
        levels = p.levels; muted = []; master = p.master; preset = p.id
        UserDefaults.standard.set(p.id, forKey: SettingsKeys.soundPreset.name)
    }

    func pushToEngine() {
        var lv: [MRLayer: Double] = [:]
        for l in MixerLayer.all { if let layer = MRLayer(rawValue: l.id) { lv[layer] = Double(level(l.id)) / 100 } }
        MRSound.shared.setMixer(levels: lv, muted: Set(muted.compactMap(MRLayer.init(rawValue:))), master: Double(master) / 100)
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(master, forKey: SettingsKeys.soundMaster.name)
        if let j = try? JSONEncoder().encode(levels) { d.set(String(data: j, encoding: .utf8), forKey: SettingsKeys.soundLevelsJSON.name) }
        if let j = try? JSONEncoder().encode(muted) { d.set(String(data: j, encoding: .utf8), forKey: SettingsKeys.soundMutedJSON.name) }
        pushToEngine()
    }
}

// MARK: - Views

struct SoundsPane: View {
    @AppStorage(SettingsKeys.uiSounds.name) private var uiSounds = SettingsKeys.uiSounds.defaultValue
    @Environment(\.mrPalette) private var p

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            MixerLayersCard().frame(width: 504)
            VStack(alignment: .leading, spacing: 0) {
                MixerAnnouncementsCard().frame(width: 408)
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("UI sounds")).font(.mr(.ui, size: 14, weight: 500))
                        Text(L("Taps, tears and stamps. Off silences every effect except announcements."))
                            .font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    MRSwitch(L("UI sounds"), isOn: $uiSounds)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .mrGlass(cornerRadius: MRRadius.card, elevation: .e1)
                .padding(.top, 16)
                HStack(spacing: 10) {
                    Button { MRSound.shared.play(.chime(.board)) } label: {
                        HStack(spacing: 8) { MRIcon(.play, size: 14); Text(L("Play boarding chime")) }
                    }.buttonStyle(MRButtonStyle(.secondary, size: .sm))
                    Button(L("Play seatbelt chime")) { MRSound.shared.play(.seatbelt) }.buttonStyle(MRButtonStyle(.tertiary, size: .sm))
                }.padding(.top, 14)
            }.frame(width: 408)
        }
        .frame(width: 940, alignment: .topLeading)
    }
}

struct MixerLayersCard: View {
    @State private var m = MixerModel.shared
    @Environment(\.mrPalette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Cabin sound")).font(.mr(.ui, size: 17, weight: 600))
                Spacer()
                MRSwitch(L("Cabin sound"), isOn: Binding(get: { MRSound.shared.settings.cabinSoundEnabled },
                                                         set: { MRSound.shared.setCabinSound($0) }))
                    .padding(.trailing, 6)
                Text("\(m.master)%").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
            }.padding(.horizontal, 4)
            HStack(spacing: 12) {
                MRIcon(.sound, size: 18).foregroundStyle(p.text2.color)
                Text(L("Master")).font(.mr(.ui, size: 14, weight: 500)).frame(width: 60, alignment: .leading)
                MRSlider(value: Binding(get: { Double(m.master) }, set: { m.master = Int($0.rounded()) }), in: 0...100, step: 1)
                    .accessibilityLabel(L("Master volume"))
            }.frame(height: 42).padding(.horizontal, 4).padding(.top, 4)
            HStack(spacing: 8) {
                ForEach(MixerPreset.all) { preset in
                    PresetChip(preset: preset, selected: m.preset == preset.id && m.levels == preset.levels) { m.apply(preset) }
                }
            }.padding(.top, 6).padding(.bottom, 8)
            MRDivider()
            VStack(spacing: 0) {
                ForEach(MixerLayer.all) { layer in LayerRow(layer: layer, model: m) }
            }.padding(.top, 6)
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 18)
        .mrGlass(cornerRadius: 28, elevation: .e3)
    }
}

private struct PresetChip: View {
    let preset: MixerPreset
    let selected: Bool
    let action: () -> Void
    @Environment(\.mrPalette) private var p
    var body: some View {
        let c = Color(hex: preset.colorHex)
        Button(action: action) {
            Text(preset.name).font(.mr(.ui, size: 12, weight: 500)).foregroundStyle(c)
                .padding(.horizontal, 14).frame(height: 30)
                .background(selected ? c.opacity(0.20) : p.fill1.color, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? c : p.strokeHair.color, lineWidth: selected ? 1.5 : 1))
                .shadow(color: selected ? c.opacity(0.3) : .clear, radius: 11)
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct LayerRow: View {
    let layer: MixerLayer
    @Bindable var model: MixerModel
    @Environment(\.mrPalette) private var p

    var body: some View {
        let muted = model.muted.contains(layer.id)
        let v = model.level(layer.id)
        HStack(spacing: 12) {
            Button {
                if muted { model.muted.remove(layer.id) } else { model.muted.insert(layer.id) }
            } label: {
                Circle().strokeBorder(p.text3.color, lineWidth: 1.5).frame(width: 18, height: 18)
                    .overlay(Circle().fill(p.accent1.color).frame(width: 8, height: 8).scaleEffect(muted ? 0 : 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .animation(MRMotion.snappy, value: muted)
            .accessibilityLabel("\(layer.name) \(muted ? L("muted") : L("on"))")
            .accessibilityAddTraits(.isToggle)
            Text(layer.name).font(.mr(.ui, size: 14, weight: 500)).foregroundStyle(muted ? p.text3.color : p.text1.color)
                .frame(width: 98, alignment: .leading)
            Wave(id: layer.id, amp: muted || v == 0 ? 0 : Double(v)).stroke(p.accent2.color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 22).opacity(muted || v == 0 ? 0.3 : 0.95)
            MRSlider(value: Binding(get: { Double(v) }, set: { model.levels[layer.id] = Int($0.rounded()); model.preset = nil }), in: 0...100, step: 1)
                .opacity(muted ? 0.4 : 1).accessibilityLabel("\(layer.name) \(L("level"))")
            Text("\(v)").font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color).frame(width: 30, alignment: .trailing)
        }
        .frame(height: 42).padding(.horizontal, 4)
    }
}

/// The small waveform glyph (mixer `wave()`), frozen at t = 3.2 like the canvas.
private struct Wave: Shape {
    let id: String
    let amp: Double
    nonisolated func path(in rect: CGRect) -> Path {
        let a = amp == 0 ? 0.5 : max(0.5, amp / 100 * 9)
        var seed = UInt64(truncatingIfNeeded: id.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) })
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        let t = 3.2
        var path = Path()
        for i in 0...32 {
            let x = Double(i * 2), ph = Double(i) / 32 * .pi * 2
            let y: Double
            switch id {
            case "ocean": y = sin(ph * 1.3 + t * 1.2) * a
            case "hum": y = sin(ph * 3 + t * 5) * a * 0.5
            case "music": y = sin(ph * 2 + t * 3) * a * sin(ph * 0.8 + 1) + sin(ph * 7 + t * 4) * a * 0.25
            default:
                let f: Double = id == "rain" ? 14 : id == "forest" ? 8 : id == "brown" ? 3 : 10
                y = (sin(ph * f + t * 6 + rnd() * 6) * 0.7 + (rnd() - 0.5)) * a * 0.8
            }
            let pt = CGPoint(x: rect.minX + x * rect.width / 64, y: rect.minY + (11 - y) * rect.height / 22)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

struct MixerAnnouncementsCard: View {
    @AppStorage(SettingsKeys.announceDuck.name) private var duck = SettingsKeys.announceDuck.defaultValue
    @AppStorage(SettingsKeys.announceCaptain.name) private var captain = SettingsKeys.announceCaptain.defaultValue
    @AppStorage(SettingsKeys.announceCrew.name) private var crew = SettingsKeys.announceCrew.defaultValue
    @AppStorage(SettingsKeys.announceSeatbelt.name) private var belt = SettingsKeys.announceSeatbelt.defaultValue
    @AppStorage(SettingsKeys.announceHeadsUp.name) private var head = SettingsKeys.announceHeadsUp.defaultValue
    @AppStorage(SettingsKeys.announceATC.name) private var atc = SettingsKeys.announceATC.defaultValue
    @Environment(\.mrPalette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("Announcements")).font(.mr(.ui, size: 17, weight: 600)).padding(.horizontal, 4).padding(.bottom, 4)
            row(L("Duck announcements"), L("Ambient sound dips 6 dB while the captain speaks."), $duck)
            row(L("Captain announcements"), L("Short, warm, never more than three a flight."), $captain)
            row(L("Cabin crew chimes"), L("A soft two-note chime at phase changes."), $crew)
            row(L("Seatbelt sign"), L("Chime and light when the plane takes off and lands."), $belt)
            row(L("Landing heads-up (5 min before)"), L("A quiet notice before descent so you can wrap up."), $head)
            row(L("ATC chatter"), L("Faint radio murmur in the background."), $atc)
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 18)
        .mrGlass(cornerRadius: 28, elevation: .e3)
    }

    private func row(_ t: String, _ sub: String, _ b: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(t).font(.mr(.ui, size: 14, weight: 500))
                Text(sub).font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            MRSwitch(t, isOn: b)
        }
        .frame(minHeight: 46).padding(.horizontal, 4)
    }
}
