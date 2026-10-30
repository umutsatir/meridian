import Foundation
import Testing
import MeridianCore
@testable import MeridianFocus

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }
private let discord = AppInfo(bundleID: "com.hnc.Discord", name: "Discord")
private let xcode = AppInfo(bundleID: "com.apple.dt.Xcode", name: "Xcode")
private let list = BlockList(apps: ["com.hnc.Discord", "com.apple.dock", "app.meridian.Meridian"])

private func flight(_ state: String, policy: PausePolicy = .normal, minutes: Double? = 42) -> Flight {
    var f = Flight(originIata: "LHR", destinationIata: "CDG", scenarioID: "study", policy: policy,
                   durationSec: minutes.map { $0 * 60 }, routeDistanceKm: 348, seed: 1)
    switch state {
    case "planned": break
    case "boarding": try! f.board()
    case "inFlight": try! f.board(); try! f.takeOff(at: t0)
    case "paused": try! f.board(); try! f.takeOff(at: t0); try! f.startPause(at: at(60))
    case "onBreak": try! f.board(); try! f.takeOff(at: t0); try! f.startBreak(at: at(60))
    case "landed": try! f.board(); try! f.takeOff(at: t0); f.settle(at: at(10_000))
    case "diverted": try! f.board(); try! f.takeOff(at: t0); try! f.landEarly(at: at(60))
    default: fatalError(state)
    }
    return f
}

@Suite struct EnforcerTests {
    @Test(arguments: BlockMode.allCases, ["planned", "boarding", "paused", "onBreak", "landed", "diverted"])
    func staysSilentOutsideActiveFlight(mode: BlockMode, state: String) {
        var e = FocusEnforcer(mode: mode, list: list)
        // Flexible so that "paused" can be built.
        let f = flight(state, policy: .flexible)
        #expect(e.evaluate(flight: f, destinationName: "Paris", app: discord, now: at(120)) == .none)
        #expect(e.violationCount == 0)
    }

    @Test func offModeNeverIntervenesOrCounts() {
        var e = FocusEnforcer(mode: .off, list: list)
        #expect(e.evaluate(flight: flight("inFlight"), destinationName: nil, app: discord, now: at(120)) == .none)
        #expect(e.violationCount == 0)
    }

    @Test func nudgeShowsToastWithDestinationAndTimeLeft() {
        var e = FocusEnforcer(mode: .nudge, list: list)
        let r = e.evaluate(flight: flight("inFlight"), destinationName: "Paris", app: discord, now: at(24 * 60))
        #expect(r == .nudge(NudgeToast(appName: "Discord", destinationName: "Paris", remainingMinutes: 18)))
    }

    @Test func overlayOffersReturnBreakAndLandEarly() {
        var e = FocusEnforcer(mode: .strictOverlay, list: list)
        let r = e.evaluate(flight: flight("inFlight"), destinationName: "Paris", app: discord, now: at(24 * 60 + 1))
        guard case .overlay(let o) = r else { Issue.record("expected overlay"); return }
        #expect(o.remainingMinutes == 18) // 17 min 59 s rounds up
        #expect(o.actions == [.returnToFocus, .takeBreak, .landEarly])
    }

    @Test func strictPolicyHidesLandEarly() {
        var e = FocusEnforcer(mode: .strictOverlay, list: list)
        let r = e.evaluate(flight: flight("inFlight", policy: .strict), destinationName: "Paris", app: discord, now: at(60))
        guard case .overlay(let o) = r else { Issue.record("expected overlay"); return }
        #expect(o.actions == [.returnToFocus, .takeBreak])
    }

    @Test func freeFlightCanAlwaysLandSoItKeepsTheOption() {
        var e = FocusEnforcer(mode: .strictOverlay, list: list)
        let r = e.evaluate(flight: flight("inFlight", policy: .strict, minutes: nil), destinationName: nil, app: discord, now: at(60))
        guard case .overlay(let o) = r else { Issue.record("expected overlay"); return }
        #expect(o.remainingMinutes == nil)
        #expect(o.actions.contains(.landEarly))
    }

    @Test func unlistedAppsAreIgnored() {
        var e = FocusEnforcer(mode: .strictOverlay, list: list)
        #expect(e.evaluate(flight: flight("inFlight"), destinationName: nil, app: xcode, now: at(60)) == .none)
        #expect(e.violationCount == 0)
    }

    @Test func ourOwnAppAndSystemUIAreNeverBlockedEvenWhenListed() {
        var e = FocusEnforcer(mode: .strictOverlay, list: list, ownBundleIDs: ["app.meridian.Meridian"])
        let f = flight("inFlight")
        let own = AppInfo(bundleID: "app.meridian.Meridian", name: "Meridian")
        let dock = AppInfo(bundleID: "com.apple.dock", name: "Dock")
        #expect(e.evaluate(flight: f, destinationName: nil, app: own, now: at(60)) == .none)
        #expect(e.evaluate(flight: f, destinationName: nil, app: dock, now: at(61)) == .none)
        #expect(e.violationCount == 0)
    }

    @Test func cooldownSuppressesRepeatsButStillCountsViolations() {
        var e = FocusEnforcer(mode: .nudge, list: list, cooldown: 60)
        let f = flight("inFlight")
        #expect(e.evaluate(flight: f, destinationName: nil, app: discord, now: at(100)) != .none)
        #expect(e.evaluate(flight: f, destinationName: nil, app: discord, now: at(130)) == .none)
        #expect(e.evaluate(flight: f, destinationName: nil, app: discord, now: at(160)) != .none) // 60 s later
        #expect(e.violationCount == 3)
        #expect(e.violationsByApp["com.hnc.Discord"] == 3)
    }

    @Test func cooldownIsPerApp() {
        let other = AppInfo(bundleID: "ru.keepcoder.Telegram", name: "Telegram")
        var e = FocusEnforcer(mode: .nudge, list: BlockList(apps: ["com.hnc.Discord", "ru.keepcoder.Telegram"]))
        let f = flight("inFlight")
        #expect(e.evaluate(flight: f, destinationName: nil, app: discord, now: at(100)) != .none)
        #expect(e.evaluate(flight: f, destinationName: nil, app: other, now: at(101)) != .none)
    }

    @Test func newFlightResetsCountersAndCooldown() {
        var e = FocusEnforcer(mode: .nudge, list: list)
        #expect(e.evaluate(flight: flight("inFlight"), destinationName: nil, app: discord, now: at(100)) != .none)
        #expect(e.violationCount == 1)
        let next = flight("inFlight") // new UUID
        #expect(e.evaluate(flight: next, destinationName: nil, app: discord, now: at(101)) != .none)
        #expect(e.violationCount == 1)
    }

    @Test func silentWhileHeldThenActiveAgain() throws {
        var e = FocusEnforcer(mode: .nudge, list: list, cooldown: 0)
        var f = flight("inFlight", policy: .flexible)
        try f.startPause(at: at(60))
        #expect(e.evaluate(flight: f, destinationName: nil, app: discord, now: at(90)) == .none)
        try f.resume(at: at(120))
        #expect(e.evaluate(flight: f, destinationName: nil, app: discord, now: at(130)) != .none)
    }
}

@Suite struct ListTests {
    @Test func presetsHaveContent() {
        for p in BlockPreset.allCases {
            #expect(!p.list.apps.isEmpty && !p.list.domains.isEmpty, "\(p)")
        }
        #expect(BlockPreset.video.list.domains.contains("youtube.com"))
        #expect(BlockPreset.social.list.apps.contains("com.hnc.Discord"))
    }

    @Test func presetsNeverContainSystemSurfaces() {
        for p in BlockPreset.allCases {
            #expect(p.list.apps.isDisjoint(with: FocusEnforcer.systemBundleIDs), "\(p)")
        }
    }

    @Test func domainMatchingCoversSubdomainsAndCase() {
        let l = BlockList(domains: ["YouTube.com"])
        #expect(l.blocksDomain("www.youtube.com"))
        #expect(l.blocksDomain("m.YouTube.com"))
        #expect(!l.blocksDomain("notyoutube.com"))
    }

    @Test func unionMergesLists() {
        let merged = BlockPreset.social.list.union(BlockPreset.games.list)
        #expect(merged.apps.contains("com.valvesoftware.steam") && merged.apps.contains("com.hnc.Discord"))
    }

    @Test func settingsRoundTripThroughCodable() throws {
        let s = FocusSettings(mode: .strictOverlay, list: BlockPreset.video.list,
                              filter: FocusFilterPlan(isEnabled: true, focusID: "com.apple.focus.work"))
        let back = try JSONDecoder().decode(FocusSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}

@Suite struct FilterPlanTests {
    let plan = FocusFilterPlan(isEnabled: true, focusID: "com.apple.focus.work")

    @Test func activatesAtTakeOffAndDeactivatesAtLanding() {
        #expect(plan.action(from: .boarding, to: .inFlight, optedOut: false) == .activate(focusID: "com.apple.focus.work"))
        #expect(plan.action(from: .inFlight, to: .landed, optedOut: false) == .deactivate(focusID: "com.apple.focus.work"))
        #expect(plan.action(from: .inFlight, to: .diverted, optedOut: false) == .deactivate(focusID: "com.apple.focus.work"))
        #expect(plan.action(from: .onBreak, to: .landed, optedOut: false) == .deactivate(focusID: "com.apple.focus.work"))
    }

    @Test func breaksAndRelaunchesDoNothing() {
        #expect(plan.action(from: .inFlight, to: .onBreak, optedOut: false) == nil)
        #expect(plan.action(from: .onBreak, to: .inFlight, optedOut: false) == nil)
        #expect(plan.action(from: .inFlight, to: .inFlight, optedOut: false) == nil)
        #expect(plan.action(from: .planned, to: .boarding, optedOut: false) == nil)
    }

    @Test func optOutDisabledAndMissingFocusDoNothing() {
        #expect(plan.action(from: .boarding, to: .inFlight, optedOut: true) == nil)
        #expect(FocusFilterPlan(isEnabled: false, focusID: "x").action(from: .boarding, to: .inFlight, optedOut: false) == nil)
        #expect(FocusFilterPlan(isEnabled: true, focusID: nil).action(from: .boarding, to: .inFlight, optedOut: false) == nil)
    }
}

@Suite struct SourceTests {
    @Test func manualSourceDeliversActivationsInOrder() async {
        let source = ManualFrontmostSource()
        source.activate(xcode)
        source.activate(discord)
        source.finish()
        var seen: [String] = []
        for await app in source.changes { seen.append(app.bundleID) }
        #expect(seen == ["com.apple.dt.Xcode", "com.hnc.Discord"])
    }
}
