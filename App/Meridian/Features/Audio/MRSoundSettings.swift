import Foundation
import Observation
#if canImport(Intents)
import Intents
#endif

/// A mixer preset (levels 0...1 per layer plus master), values from the Mixer artboard.
nonisolated struct MRSoundPreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let levels: [MRLayer: Double]
    let master: Double

    static let deepWork = MRSoundPreset(id: "deep", title: "Deep Work",
        levels: [.hum: 0.55, .rain: 0, .ocean: 0, .forest: 0, .brown: 0.38, .pink: 0, .music: 0], master: 0.72)
    static let nightFlight = MRSoundPreset(id: "night", title: "Night Flight",
        levels: [.hum: 0.70, .rain: 0, .ocean: 0, .forest: 0, .brown: 0.22, .pink: 0, .music: 0.34], master: 0.60)
    static let rainyRead = MRSoundPreset(id: "rainy", title: "Rainy Read",
        levels: [.hum: 0.30, .rain: 0.64, .ocean: 0, .forest: 0, .brown: 0, .pink: 0, .music: 0.42], master: 0.68)

    static let all: [MRSoundPreset] = [deepWork, nightFlight, rainyRead]

    /// Looks up by id; `"rain"` (used by the C10 artboard) is an alias of `"rainy"`.
    static func named(_ id: String) -> MRSoundPreset? {
        all.first { $0.id == id } ?? (id == "rain" ? rainyRead : nil)
    }
}

/// User preferences of the sound engine, persisted in UserDefaults.
@MainActor
@Observable
final class MRSoundSettings {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let prefix = "meridian.sound."

    /// "UI sounds": taps, tears, stamps, printer. Off silences every effect except announcements.
    var uiSoundsEnabled: Bool { didSet { defaults.set(uiSoundsEnabled, forKey: prefix + "ui") } }
    /// Master switch of all announcements (each group also has its own switch).
    var announcementsEnabled: Bool { didSet { defaults.set(announcementsEnabled, forKey: prefix + "announcements") } }
    var enabledGroups: Set<AnnouncementGroup> {
        didSet { defaults.set(enabledGroups.map(\.rawValue).sorted(), forKey: prefix + "groups") }
    }
    /// Ambient sound dips 6 dB while an announcement plays.
    var duckAnnouncements: Bool { didSet { defaults.set(duckAnnouncements, forKey: prefix + "duck") } }
    /// Play UI sounds and announcements although Do Not Disturb / a Focus is active.
    var allowDuringDoNotDisturb: Bool { didSet { defaults.set(allowDuringDoNotDisturb, forKey: prefix + "dnd") } }
    /// Mixer master 0...1.
    var master: Double { didSet { defaults.set(master, forKey: prefix + "master") } }
    var layerLevels: [MRLayer: Double] {
        didSet { defaults.set(Dictionary(uniqueKeysWithValues: layerLevels.map { ($0.key.rawValue, $0.value) }), forKey: prefix + "levels") }
    }
    var mutedLayers: Set<MRLayer> {
        didSet { defaults.set(mutedLayers.map(\.rawValue).sorted(), forKey: prefix + "muted") }
    }
    /// Last applied preset id, if the levels still match it.
    var presetID: String? { didSet { defaults.set(presetID, forKey: prefix + "preset") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let p = "meridian.sound."
        func bool(_ k: String, _ d: Bool) -> Bool { defaults.object(forKey: p + k) == nil ? d : defaults.bool(forKey: p + k) }
        uiSoundsEnabled = bool("ui", true)
        announcementsEnabled = bool("announcements", true)
        duckAnnouncements = bool("duck", true)
        allowDuringDoNotDisturb = bool("dnd", false)
        if let raw = defaults.stringArray(forKey: p + "groups") {
            enabledGroups = Set(raw.compactMap(AnnouncementGroup.init(rawValue:)))
        } else {
            enabledGroups = Set(AnnouncementGroup.allCases.filter(\.defaultEnabled))
        }
        master = defaults.object(forKey: p + "master") == nil ? MRSoundPreset.deepWork.master : defaults.double(forKey: p + "master")
        if let raw = defaults.dictionary(forKey: p + "levels") as? [String: Double] {
            var lv: [MRLayer: Double] = [:]
            for (k, v) in raw { if let l = MRLayer(rawValue: k) { lv[l] = min(1, max(0, v)) } }
            layerLevels = lv
        } else {
            layerLevels = MRSoundPreset.deepWork.levels
        }
        mutedLayers = Set((defaults.stringArray(forKey: p + "muted") ?? []).compactMap(MRLayer.init(rawValue:)))
        presetID = defaults.object(forKey: p + "preset") == nil ? MRSoundPreset.deepWork.id : defaults.string(forKey: p + "preset")
    }

    func level(of layer: MRLayer) -> Double { layerLevels[layer] ?? 0 }

    func isEnabled(_ group: AnnouncementGroup) -> Bool { enabledGroups.contains(group) }
    func setEnabled(_ group: AnnouncementGroup, _ on: Bool) {
        if on { enabledGroups.insert(group) } else { enabledGroups.remove(group) }
    }
}

/// Do Not Disturb / Focus probe. macOS has no public "is DND on" API; `INFocusStatusCenter` answers only when the user has
/// granted Focus Status access (the app never asks for it on its own), otherwise it reports `false` (assume allowed).
@MainActor
enum MRFocusProbe {
    static func isDoNotDisturbActive() -> Bool {
        #if canImport(Intents)
        let center = INFocusStatusCenter.default
        guard center.authorizationStatus == .authorized else { return false }
        return center.focusStatus.isFocused ?? false
        #else
        return false
        #endif
    }
}
