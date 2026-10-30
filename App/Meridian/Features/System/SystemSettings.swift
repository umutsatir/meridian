import AppKit
import Observation
import SwiftUI

enum MiniMapSize: String, CaseIterable, Codable {
    case s, m, l
    var dimensions: CGSize {
        switch self {
        case .s: CGSize(width: 360, height: 200)
        case .m: CGSize(width: 480, height: 270)
        case .l: CGSize(width: 640, height: 360)
        }
    }
    var title: String { switch self { case .s: "Small"; case .m: "Medium"; case .l: "Large" } }
    var next: MiniMapSize { switch self { case .s: .m; case .m: .l; case .l: .s } }

    /// Nearest preset for a dragged width (the design snaps on release).
    static func nearest(width: CGFloat) -> MiniMapSize {
        allCases.min { abs($0.dimensions.width - width) < abs($1.dimensions.width - width) } ?? .m
    }
}

enum MiniMapCorner: String, Codable {
    case tl, tr, bl, br
}

/// What the mini map remembers for one display (PRD SYS-2: size and position per screen).
struct MiniMapScreenState: Codable, Equatable {
    var corner: MiniMapCorner = .br
    var size: MiniMapSize = .m
}

/// Preferences of the system surfaces. Stored in UserDefaults so a relaunch restores them.
@MainActor
@Observable
final class SystemSettings {
    private let defaults: UserDefaults

    var miniMapEnabled: Bool { didSet { defaults.set(miniMapEnabled, forKey: "sys.mini.enabled") } }
    var miniMapOpacity: Double { didSet { defaults.set(miniMapOpacity, forKey: "sys.mini.opacity") } }
    var clickThrough: Bool { didSet { defaults.set(clickThrough, forKey: "sys.mini.clickThrough") } }
    var keepAwake: Bool { didSet { defaults.set(keepAwake, forKey: "sys.keepAwake") } }
    var soundOn: Bool { didSet { defaults.set(soundOn, forKey: "sys.sound") } }

    // Notifications (M05): every kind can be switched off.
    var notifyBoarding: Bool { didSet { defaults.set(notifyBoarding, forKey: "sys.notify.boarding") } }
    var notifyGate: Bool { didSet { defaults.set(notifyGate, forKey: "sys.notify.gate") } }
    var notifyLanding: Bool { didSet { defaults.set(notifyLanding, forKey: "sys.notify.landing") } }
    var notifyFriend: Bool { didSet { defaults.set(notifyFriend, forKey: "sys.notify.friend") } }

    private(set) var screens: [String: MiniMapScreenState]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        miniMapEnabled = bool("sys.mini.enabled", true)
        miniMapOpacity = defaults.object(forKey: "sys.mini.opacity") as? Double ?? 1
        clickThrough = bool("sys.mini.clickThrough", false)
        keepAwake = bool("sys.keepAwake", true)
        soundOn = bool("sys.sound", true)
        notifyBoarding = bool("sys.notify.boarding", true)
        notifyGate = bool("sys.notify.gate", true)
        notifyLanding = bool("sys.notify.landing", true)
        notifyFriend = bool("sys.notify.friend", true)
        screens = defaults.data(forKey: "sys.mini.screens")
            .flatMap { try? JSONDecoder().decode([String: MiniMapScreenState].self, from: $0) } ?? [:]
    }

    func state(for screenKey: String) -> MiniMapScreenState { screens[screenKey] ?? MiniMapScreenState() }

    func update(_ screenKey: String, _ change: (inout MiniMapScreenState) -> Void) {
        var s = state(for: screenKey)
        change(&s)
        screens[screenKey] = s
        if let data = try? JSONEncoder().encode(screens) { defaults.set(data, forKey: "sys.mini.screens") }
    }

    /// Stable key of a display (`NSScreenNumber`).
    static func key(for screen: NSScreen?) -> String {
        guard let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return "main" }
        return number.stringValue
    }
}
