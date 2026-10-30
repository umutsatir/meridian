import Foundation
import Testing
@testable import MeridianCore

@Suite struct CollectionTests {
    @Test func tiersAtExactThresholds() {
        #expect(MembershipTier.tier(forKm: 0) == .departure)
        #expect(MembershipTier.tier(forKm: 999.9) == .departure)
        #expect(MembershipTier.tier(forKm: 1_000) == .cruise)
        #expect(MembershipTier.tier(forKm: 40_075) == .equator)
        #expect(MembershipTier.tier(forKm: 1_000_000) == .obsidian)
    }

    @Test func unlockingReportsEachTierOnce() {
        #expect(MembershipTier.unlocked(from: 900, to: 1_100) == [.cruise])
        #expect(MembershipTier.unlocked(from: 1_100, to: 1_200).isEmpty)
        #expect(MembershipTier.unlocked(from: 900, to: 6_000) == [.cruise, .jetstream])
        #expect(MembershipTier.unlocked(from: 0, to: 0).isEmpty)
    }

    @Test func ticketIdentityIsDeterministicAndWellFormed() {
        let a = TicketIdentity(seed: 42), b = TicketIdentity(seed: 42)
        #expect(a == b)
        #expect(a.flightNumber.hasPrefix("MR") && a.flightNumber.count == 6)
        #expect(a.gate.count >= 2)
        #expect(TicketIdentity(seed: 43) != a)
    }

    @Test func streakCountsConsecutiveDaysAndSurvivesAnEmptyToday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000 + 12 * 3600)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: -offset, to: now)! }
        #expect(Streak.current(landingDates: [], now: now, calendar: cal) == 0)
        #expect(Streak.current(landingDates: [day(0), day(1), day(2)], now: now, calendar: cal) == 3)
        #expect(Streak.current(landingDates: [day(1), day(2)], now: now, calendar: cal) == 2)
        #expect(Streak.current(landingDates: [day(2), day(3)], now: now, calendar: cal) == 0)
        #expect(Streak.current(landingDates: [day(0), day(0), day(2)], now: now, calendar: cal) == 1)
    }
}
