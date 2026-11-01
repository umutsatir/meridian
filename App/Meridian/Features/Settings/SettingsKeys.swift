import Foundation

/// A UserDefaults key with its default. Every setting of the app lives in `SettingsKeys`,
/// so other features read the same key (`SettingsKeys.holdToLand.current`).
struct SettingKey<Value>: Sendable where Value: Sendable {
    let name: String
    let defaultValue: Value
    init(_ name: String, _ defaultValue: Value) { self.name = name; self.defaultValue = defaultValue }
}

extension SettingKey where Value == Bool {
    var current: Bool { UserDefaults.standard.object(forKey: name) as? Bool ?? defaultValue }
}
extension SettingKey where Value == Int {
    var current: Int { UserDefaults.standard.object(forKey: name) as? Int ?? defaultValue }
}
extension SettingKey where Value == String {
    var current: String { UserDefaults.standard.string(forKey: name) ?? defaultValue }
}

/// Single source of truth for settings keys and defaults (PRD §9.15; defaults match the "Used" column).
enum SettingsKeys {
    // General
    static let showInMenuBar = SettingKey("settings.general.menuBar", true)
    static let showInDock = SettingKey("settings.general.dock", true)
    static let keepFlyingOnClose = SettingKey("settings.general.keepFlying", true)
    static let language = SettingKey("settings.general.language", "system")
    static let distanceUnit = SettingKey("settings.general.distanceUnit", 0)        // 0 km, 1 mi
    static let timeFormat = SettingKey("settings.general.timeFormat", 0)            // 0 24 h, 1 12 h
    static let resumeAfterSleep = SettingKey("settings.general.resume", true)
    static let holdToLand = SettingKey("settings.general.holdToLand", true)
    // Flight
    static let homeAirport = SettingKey("settings.flight.homeAirport", "LHR")
    static let defaultScenario = SettingKey("settings.flight.defaultScenario", "code")
    static let seatPreference = SettingKey("settings.flight.seat", 0)               // 0 window, 1 aisle
    static let quickStartChecksIn = SettingKey("settings.flight.quickStartChecksIn", false)
    static let ticketPrinting = SettingKey("settings.flight.printing", 0)           // full, quick, off
    static let takeoffSequence = SettingKey("settings.flight.takeoff", 0)           // full, short, skip
    static let tearFeedback = SettingKey("settings.flight.tear", true)
    static let landingStamp = SettingKey("settings.flight.stamp", true)
    static let landingHeadsUp = SettingKey("settings.flight.headsUp", "5")          // minutes before, "off"
    static let askWhatGotDone = SettingKey("settings.flight.notes", true)
    // Maps
    static let mapStyle = SettingKey("settings.maps.style", 0)                      // terra, mono, standard, satellite
    static let mapEngine = SettingKey("settings.maps.engine", 0)                    // Apple Maps, Illustrated
    static let homeGlobe = SettingKey("settings.maps.homeGlobe", 0)                 // Realistic, Illustrated
    static let labelLanguage = SettingKey("settings.maps.labelLanguage", 1)         // local, english, both
    static let bothNames = SettingKey("settings.maps.bothNames", true)
    static let borders = SettingKey("settings.maps.borders", true)
    static let cityNames = SettingKey("settings.maps.cities", true)
    static let planeTrail = SettingKey("settings.maps.trail", true)
    // Appearance
    static let theme = SettingKey("settings.appearance.theme", "dark")              // system, dark, light
    static let appIcon = SettingKey("settings.appearance.icon", "b")                // a, b, c
    static let accent = SettingKey("settings.appearance.accent", "sky")
    // Notifications
    static let notifBoarding = SettingKey("settings.notif.boarding", true)
    static let notifGateOpens = SettingKey("settings.notif.gate", true)
    static let notifPrepareLanding = SettingKey("settings.notif.prepare", true)
    static let notifLanded = SettingKey("settings.notif.landed", false)
    static let notifFriendJoined = SettingKey("settings.notif.friendJoined", true)
    static let notifFriendLanded = SettingKey("settings.notif.friendLanded", true)
    static let notifInvitations = SettingKey("settings.notif.invites", true)
    static let notifTimeSensitive = SettingKey("settings.notif.timeSensitive", true)
    static let quietHours = SettingKey("settings.notif.quiet", 1)                   // off, 22-07, custom
    // Privacy
    static let anonymousUsage = SettingKey("settings.privacy.usage", false)
    static let showFlightsToFriends = SettingKey("settings.privacy.showFlights", true)
    // iCloud
    static let iCloudRequested = SettingKey("settings.icloud.requested", false)
    // Sounds
    static let uiSounds = SettingKey("settings.sounds.ui", true)
    static let soundMaster = SettingKey("settings.sounds.master", 72)
    static let soundPreset = SettingKey("settings.sounds.preset", "deep")
    static let soundLevelsJSON = SettingKey("settings.sounds.levels", "")
    static let soundMutedJSON = SettingKey("settings.sounds.muted", "")
    static let announceDuck = SettingKey("settings.sounds.duck", true)
    static let announceCaptain = SettingKey("settings.sounds.captain", true)
    static let announceCrew = SettingKey("settings.sounds.crew", true)
    static let announceSeatbelt = SettingKey("settings.sounds.seatbelt", true)
    static let announceHeadsUp = SettingKey("settings.sounds.headsUp", true)
    static let announceATC = SettingKey("settings.sounds.atc", false)
    // Focus
    static let focusSettingsJSON = SettingKey("settings.focus.json", "")
    static let focusAllowEditor = SettingKey("settings.focus.allowEditor", true)
    static let focusLiftOnBreak = SettingKey("settings.focus.liftOnBreak", true)
    // Shortcuts (JSON dictionary id -> display keys)
    static let shortcutsJSON = SettingKey("settings.shortcuts.json", "")

    /// Every key name, for "reset settings" and for tests.
    static let allNames: [String] = [
        showInMenuBar.name, showInDock.name, keepFlyingOnClose.name, language.name, distanceUnit.name, timeFormat.name,
        resumeAfterSleep.name, holdToLand.name, homeAirport.name, defaultScenario.name, seatPreference.name,
        quickStartChecksIn.name, ticketPrinting.name, takeoffSequence.name, tearFeedback.name, landingStamp.name,
        landingHeadsUp.name, askWhatGotDone.name, mapStyle.name, mapEngine.name, homeGlobe.name, labelLanguage.name, bothNames.name, borders.name,
        cityNames.name, planeTrail.name, theme.name, appIcon.name, accent.name, notifBoarding.name, notifGateOpens.name,
        notifPrepareLanding.name, notifLanded.name, notifFriendJoined.name, notifFriendLanded.name,
        notifInvitations.name, notifTimeSensitive.name, quietHours.name, anonymousUsage.name,
        showFlightsToFriends.name, iCloudRequested.name, uiSounds.name, soundMaster.name, soundPreset.name,
        soundLevelsJSON.name, soundMutedJSON.name, announceDuck.name, announceCaptain.name, announceCrew.name,
        announceSeatbelt.name, announceHeadsUp.name, announceATC.name, focusSettingsJSON.name, focusAllowEditor.name,
        focusLiftOnBreak.name, shortcutsJSON.name,
    ]
}

/// Typed accessors for non-view code.
enum AppSettings {
    static var distanceInMiles: Bool { SettingsKeys.distanceUnit.current == 1 }
    static var uses12HourClock: Bool { SettingsKeys.timeFormat.current == 1 }
    static var holdToLandEnabled: Bool { SettingsKeys.holdToLand.current }
    static var resumeAfterSleepEnabled: Bool { SettingsKeys.resumeAfterSleep.current }
    /// Minutes before landing for the heads-up banner; `nil` = off.
    static var landingHeadsUpMinutes: Int? { Int(SettingsKeys.landingHeadsUp.current) }
}
