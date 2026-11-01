import MeridianCore
import MeridianMaps
import MeridianPlan
import MeridianPro
import MeridianUI
import SwiftUI

// MARK: - General

struct GeneralPane: View {
    @State private var launchAtLogin = SettingsEffects.launchAtLoginEnabled
    @AppStorage(SettingsKeys.language.name) private var language = SettingsKeys.language.defaultValue
    @Environment(\.mrPalette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(L("Launch and window")) {
                SettingsCard {
                    SettingsRow(L("Launch at login"), sub: L("Starts quietly in the menu bar.")) {
                        MRSwitch(L("Launch at login"), isOn: Binding(
                            get: { launchAtLogin },
                            set: { on in
                                launchAtLogin = on
                                if !SettingsEffects.setLaunchAtLogin(on) { launchAtLogin = SettingsEffects.launchAtLoginEnabled }
                            }))
                    }
                    PrefToggleRow(SettingsKeys.showInMenuBar, L("Show in menu bar"), L("Plane glyph and remaining time, updated every second."))
                    PrefToggleRow(SettingsKeys.showInDock, L("Show in Dock"), L("Turn off to live only in the menu bar."),
                                  onChange: { SettingsEffects.applyDock($0) })
                    PrefToggleRow(SettingsKeys.keepFlyingOnClose, L("Keep flying when the window closes"), L("The flight keeps running; the menu bar item stays."))
                }
            }
            SettingsGroup(L("Language and units")) {
                SettingsCard {
                    SettingsRow(L("Language"), sub: L("Follows System Settings.")) {
                        SelectMenu(title: L("Language"), options: [
                            ("system", L("System (%@)", Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en")?.capitalized ?? "English")),
                            ("en", "English"), ("tr", "Türkçe"),
                        ], selection: $language)
                    }
                    PrefSegmentedRow(SettingsKeys.distanceUnit, L("Distance"), options: ["km", "mi"])
                    PrefSegmentedRow(SettingsKeys.timeFormat, L("Time"), options: [L("24 h"), L("12 h")])
                }
            }
            SettingsGroup(L("Sleep and quit")) {
                SettingsCard {
                    PrefToggleRow(SettingsKeys.resumeAfterSleep, L("Resume flights after sleep or quit"),
                                  L("Your plane keeps flying while the Mac sleeps. “Flight resumed” appears when you are back."))
                    PrefToggleRow(SettingsKeys.holdToLand, L("Hold to land early"), L("Press and hold for 1.2 s so a stray click never ends a flight."))
                }
            }
        }
        .onChange(of: language) { _, new in SettingsEffects.applyLanguage(new) }
        .onAppear { launchAtLogin = SettingsEffects.launchAtLoginEnabled }
    }
}

// MARK: - Flight

struct FlightPane: View {
    @Environment(AppModel.self) private var model

    private static let commonAirports = ["LHR", "CDG", "AMS", "FRA", "MAD", "BCN", "FCO", "IST", "SAW", "ZRH", "VIE", "CPH", "DUB", "LIS",
                                         "JFK", "EWR", "LAX", "SFO", "ORD", "YYZ", "DXB", "DOH", "SIN", "HND", "ICN", "HKG", "SYD", "GRU"]

    private var homeOptions: [(value: String, label: String)] {
        var codes = Self.commonAirports
        if !codes.contains(model.plan.origin.iata) { codes.insert(model.plan.origin.iata, at: 0) }
        return codes.compactMap { code in model.airport(code).map { (code, "\($0.name) · \(code)") } }
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(L("Defaults")) {
                SettingsCard {
                    SettingsRow(L("Home airport"), sub: L("Your origin chip on the plan screen.")) {
                        SelectMenu(title: L("Home airport"), options: homeOptions,
                                   selection: Binding(get: { model.plan.origin.iata }, set: { _ = model.plan.setOrigin(iata: $0) }))
                    }
                    SettingsRow(L("Default scenario")) {
                        SelectMenu(title: L("Default scenario"),
                                   options: Scenario.defaults.map { ($0.id, $0.name) },
                                   selection: Binding(get: { model.plan.scenarioID }, set: { model.plan.setScenario(id: $0) }))
                    }
                    PrefSegmentedRow(SettingsKeys.seatPreference, L("Seat preference"), L("Used when you quick start."), options: [L("Window"), L("Aisle")])
                    PrefToggleRow(SettingsKeys.quickStartChecksIn, L("Quick start checks in automatically"), L("Skips the seat step. Uses your last scenario and duration."))
                }
            }
            SettingsGroup(L("Rituals")) {
                SettingsCard {
                    PrefSegmentedRow(SettingsKeys.ticketPrinting, L("Ticket printing"), L("The printer takes 2.4 s."), options: [L("Full"), L("Quick"), L("Off")])
                    PrefSegmentedRow(SettingsKeys.takeoffSequence, L("Take-off sequence"), L("Full is 6 s. Short is 2 s."), options: [L("Full"), L("Short"), L("Skip")])
                    PrefToggleRow(SettingsKeys.tearFeedback, L("Tear sound and haptics"), L("Follows your hand: faster pull, louder rip."))
                    PrefToggleRow(SettingsKeys.landingStamp, L("Landing stamp"), L("A 60 ms thump and a 120 ms bleed."))
                }
            }
            SettingsGroup(L("Landing")) {
                SettingsCard {
                    PrefSelectRow(SettingsKeys.landingHeadsUp, L("Landing heads-up"), L("The “prepare for landing” banner."),
                                  options: [("10", L("10 minutes before")), ("5", L("5 minutes before")), ("2", L("2 minutes before")), ("off", L("Off"))])
                    PrefToggleRow(SettingsKeys.askWhatGotDone, L("Ask what you got done"), L("A short notes prompt after you land."))
                }
            }
        }
    }
}

// MARK: - Maps

struct MapsPane: View {
    @Environment(\.mrPalette) private var p
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(L("Style")) {
                SettingsCard {
                    PrefSegmentedRow(SettingsKeys.mapStyle, L("Map style"), L("Terra is the default in dark, Standard in light."),
                                     options: ["Terra", "Mono", "Standard", "Satellite"])
                    PrefSegmentedRow(SettingsKeys.mapEngine, L("Map engine"), L("Apple Maps is the default. Illustrated is the drawn map of the design and the fallback when the map cannot load."),
                                     options: [L("Apple Maps"), L("Illustrated")])
                    PrefSegmentedRow(SettingsKeys.homeGlobe, L("Home globe"), L("Realistic shows satellite imagery. It needs Apple Maps."),
                                     options: [L("Realistic"), L("Illustrated")])
                    PrefSegmentedRow(SettingsKeys.labelLanguage, L("Label language"), options: [L("Local"), L("English"), L("Both")])
                }
            }
            SettingsGroup(L("Labels")) {
                SettingsCard {
                    PrefToggleRow(SettingsKeys.bothNames, L("Show both names for disputed places"), L("Both names appear together, in the order your region prefers."))
                    PrefToggleRow(SettingsKeys.borders, L("Show country borders"), L("Disputed borders are drawn as dashed lines."))
                    PrefToggleRow(SettingsKeys.cityNames, L("Show city names"), L("Only places above 1 million people, so the map stays calm."))
                    PrefToggleRow(SettingsKeys.planeTrail, L("Show the plane trail"), L("The accent trail behind your plane."))
                }
            }
            Text(L("Where governments name a place differently, Meridian shows both names, in the order your device region prefers. Disputed borders are drawn as dashed lines of control and are never colored as part of one country."))
                .font(.mr(.ui, size: 13, weight: 400))
                .foregroundStyle(p.text3.color)
                .frame(maxWidth: 600, alignment: .leading)
                .padding(.leading, 6).padding(.top, 2)
        }
    }
}

/// Right-hand "Preview" column of the Maps pane (`showMapPrev`).
struct MapsPreview: View {
    @Environment(\.mrPalette) private var p
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        let m = MRMapPalette.resolve(.terra, dark: dark)
        VStack(alignment: .leading, spacing: 0) {
            SettingsCap(text: L("Preview"))
            ZStack(alignment: .topLeading) {
                m.sea.color
                if MapEngine.current == .appleMaps {
                    let all = MapStyle.allCases
                    let style = MapStyleAccess.resolved(all[max(0, min(all.count - 1, SettingsKeys.mapStyle.current))])
                    MapSurface(style: style, center: Coordinate(latitude: -51.7, longitude: -59.5), zoom: 12,
                               size: CGSize(width: 260, height: 300), showsLabels: false)
                        .frame(width: 260, height: 300)
                } else {
                Canvas { ctx, _ in
                    var land = Path()
                    land.move(to: CGPoint(x: -10, y: 190))
                    land.addCurve(to: CGPoint(x: 130, y: 140), control1: CGPoint(x: 40, y: 150), control2: CGPoint(x: 90, y: 170))
                    land.addCurve(to: CGPoint(x: 270, y: 100), control1: CGPoint(x: 170, y: 110), control2: CGPoint(x: 210, y: 130))
                    let shore = land
                    land.addLine(to: CGPoint(x: 270, y: 310)); land.addLine(to: CGPoint(x: -10, y: 310)); land.closeSubpath()
                    ctx.fill(land, with: .color(m.land.color))
                    ctx.stroke(shore, with: .color(m.line.color), lineWidth: 2)
                    var dashed = Path()
                    dashed.move(to: CGPoint(x: 60, y: 214))
                    dashed.addCurve(to: CGPoint(x: 150, y: 190), control1: CGPoint(x: 90, y: 196), control2: CGPoint(x: 120, y: 206))
                    ctx.stroke(dashed, with: .color(m.label.color), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                    ctx.fill(Path(ellipseIn: CGRect(x: 100, y: 202, width: 8, height: 8)), with: .color(p.accent1.color))
                }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Falkland Islands").foregroundStyle(p.text1.color)
                    Text("Islas Malvinas").foregroundStyle(m.label.color)
                }
                .font(.mr(.ui, size: 12, weight: 500))
                .offset(x: 124, y: 196)
                Text(L("Both names on")).textCase(.uppercase)
                    .font(.mr(.mono, size: 11, weight: 500)).tracking(11 * 0.06)
                    .foregroundStyle(m.label.color)
                    .offset(x: 18, y: 18)
                VStack {
                    Spacer()
                    Text(L("Order follows your device region; you can swap it in System Settings."))
                        .font(.mr(.ui, size: 12, weight: 400)).foregroundStyle(p.text2.color)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mrGlass(cornerRadius: 14, elevation: .e1)
                        .padding(.horizontal, 14).padding(.bottom, 14)
                }
            }
            .frame(width: 260, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(p.strokeHair.color, lineWidth: 1))
            .shadow(color: p.e2.color.color, radius: p.e2.radius, y: p.e2.y)
        }
        .frame(width: 260)
    }
}

// MARK: - Notifications

struct NotificationsPane: View {
    private func ask(_ on: Bool) { if on { SettingsEffects.requestNotificationAuthorization() } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(L("Flight")) {
                SettingsCard {
                    PrefToggleRow(SettingsKeys.notifBoarding, L("Boarding call"), L("When your scheduled flight opens."), onChange: ask)
                    PrefToggleRow(SettingsKeys.notifGateOpens, L("Gate opens in 5 min"), L("For flights you booked for later."), onChange: ask)
                    PrefToggleRow(SettingsKeys.notifPrepareLanding, L("Prepare for landing"), L("5 minutes before you land."), onChange: ask)
                    PrefToggleRow(SettingsKeys.notifLanded, L("Landed"), L("After a flight ends while Meridian is in the background."), onChange: ask)
                }
            }
            SettingsGroup(L("Together")) {
                SettingsCard {
                    PrefToggleRow(SettingsKeys.notifFriendJoined, L("Friend joined your flight"), onChange: ask)
                    PrefToggleRow(SettingsKeys.notifFriendLanded, L("Friend landed"), L("Status only. There is no chat."), onChange: ask)
                    PrefToggleRow(SettingsKeys.notifInvitations, L("Flight invitations"), onChange: ask)
                }
            }
            SettingsGroup(L("Delivery")) {
                SettingsCard {
                    PrefToggleRow(SettingsKeys.notifTimeSensitive, L("Time Sensitive for the landing heads-up"), L("Breaks through a Focus so you never miss the landing."))
                    PrefSegmentedRow(SettingsKeys.quietHours, L("Quiet hours"), L("No banners, only the menu bar."),
                                     options: [L("Off"), "22:00–07:00", L("Custom")])
                }
            }
        }
    }
}

// MARK: - Account and Pro

struct AccountPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.mrPalette) private var p
    @Environment(\.showPaywall) private var showPaywall
    private var pro: ProModel { .shared }
    @AppStorage(SettingsKeys.iCloudRequested.name) private var iCloudRequested = SettingsKeys.iCloudRequested.defaultValue

    private var name: String { NSFullUserName().isEmpty ? NSUserName() : NSFullUserName() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                MRAvatarBig(initial: String(name.prefix(1)).uppercased())
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.mr(.ui, size: 17, weight: 600))
                    Text(L("%lld flights · %@ km flown", model.walletFlights.count, Int(model.totalKm).formatted()))
                        .font(.mr(.mono, size: 12, weight: 500)).foregroundStyle(p.text2.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MRPill(pro.isPro ? L("Meridian Pro") : L("Meridian Free"))
                if !pro.isPro {
                    Button(L("See Meridian Pro")) { showPaywall() }.buttonStyle(MRButtonStyle(.primary, size: .sm))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .mrGlass(cornerRadius: MRRadius.card, elevation: .e1)
            .padding(.bottom, 22)

            SettingsGroup(L("Plan")) {
                SettingsCard {
                    SettingsButtonRow(title: L("Meridian Pro"),
                                      sub: L("Adds the satellite map, extra cabin sounds and friend flights over 4 people. Everything else stays free."),
                                      button: L("See what is included")) { showPaywall() }
                }
            }
            SettingsGroup(L("iCloud")) {
                SettingsCard {
                    SettingsRow(L("Sync with iCloud"), sub: ICloudStatus.current.detail) {
                        MRSwitch(L("Sync with iCloud"), isOn: $iCloudRequested)
                            .disabled(!ICloudStatus.current.isAvailable)
                    }
                    SettingsValueRow(title: L("Family Sharing"), sub: L("Pro can be shared with up to 5 people."),
                                     value: pro.entitlement == .pro(.family) ? L("Active") : L("Not set up"))
                    SettingsButtonRow(title: L("Restore purchases"), sub: "", button: L("Restore")) { Task { await pro.restore() } }
                }
            }
            SettingsGroup(L("Account")) {
                SettingsCard {
                    SettingsButtonRow(title: L("Sign out"), sub: L("Meridian works without an account. Your flights stay on this Mac."),
                                      button: L("Sign out"), kind: .tertiary, isEnabled: false) {}
                }
            }
        }
    }
}

private struct MRAvatarBig: View {
    let initial: String
    var body: some View {
        MRAvatar(initial, tint: MRScenarioColor.study.color, size: .lg)
            .scaleEffect(56.0 / 44.0)
            .frame(width: 56, height: 56)
    }
}

/// Honest iCloud state. CloudKit is off in this build (`MeridianSchema.container(cloudKit: false)`),
/// so the row says so instead of showing a fake "Synced 2 min ago".
struct ICloudStatus {
    let isAvailable: Bool
    let detail: String

    static var current: ICloudStatus {
        ICloudStatus(isAvailable: false, detail: L("iCloud sync off. Flights are saved on this Mac only."))
    }
}

// MARK: - Data and privacy

struct PrivacyPane: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingDelete = false
    @State private var choosingFormat = false
    @State private var cacheBytes = SettingsEffects.mapCacheBytes
    @State private var toast: String?

    static let privacyURL = URL(string: "https://meridian.app/privacy")!   // TODO: final domain (Q1)
    static let termsURL = URL(string: "https://meridian.app/terms")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(L("Sharing")) {
                SettingsCard {
                    PrefToggleRow(SettingsKeys.anonymousUsage, L("Share anonymous usage data"), L("Off by default. Never includes what you tag or write."))
                    PrefToggleRow(SettingsKeys.showFlightsToFriends, L("Show my flights to friends"), L("Status only. Never the destination notes."))
                }
            }
            SettingsGroup(L("Your data")) {
                SettingsCard {
                    SettingsButtonRow(title: L("Export my flights"), sub: L("CSV or JSON, with every ticket and note."), button: L("Export…")) { choosingFormat = true }
                    SettingsButtonRow(title: L("Clear map cache"), sub: L("%@ on this Mac.", ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file)),
                                      button: L("Clear")) {
                        SettingsEffects.clearMapCache(); cacheBytes = SettingsEffects.mapCacheBytes
                    }
                    SettingsButtonRow(title: L("Delete all Meridian data"), sub: L("This removes flights, cards and stamps on every device."),
                                      button: L("Delete…"), kind: .danger) { confirmingDelete = true }
                }
            }
            SettingsGroup(L("About")) {
                SettingsCard {
                    SettingsButtonRow(title: L("Privacy policy"), sub: "", button: L("Open"), kind: .tertiary) { NSWorkspace.shared.open(Self.privacyURL) }
                    SettingsButtonRow(title: L("Terms of use"), sub: "", button: L("Open"), kind: .tertiary) { NSWorkspace.shared.open(Self.termsURL) }
                }
            }
        }
        .confirmationDialog(L("Export format"), isPresented: $choosingFormat) {
            Button("CSV") { export(.csv) }
            Button("JSON") { export(.json) }
            Button(L("Cancel"), role: .cancel) {}
        }
        .alert(L("Delete all your flights?"), isPresented: $confirmingDelete) {
            Button(L("Delete everything"), role: .destructive) { model.deleteAllData() }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("Flights, cards, stamps and your profile are removed. This cannot be undone."))
        }
    }

    private func export(_ format: FlightExport.Format) {
        _ = FlightExport.save(model.walletFlights, format: format)
    }
}

// MARK: - Environment: open the paywall

private struct ShowPaywallKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var showPaywall: () -> Void {
        get { self[ShowPaywallKey.self] }
        set { self[ShowPaywallKey.self] = newValue }
    }
}
