import Foundation
import Testing
@testable import MeridianPro

@Suite struct TrialAndPaywallTests {
    func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, in cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func timelineIsTodayDayFiveDaySeven() {
        let cal = calendar("UTC")
        let t = TrialTimeline(start: date(2026, 11, 1, in: cal), calendar: cal)
        #expect(t.steps.map(\.kind) == [.today, .reminder, .charge])
        #expect(t.steps.map(\.day) == [0, 5, 7])
        #expect(t.reminderDate == date(2026, 11, 6, in: cal))
        #expect(t.chargeDate == date(2026, 11, 8, in: cal))
    }

    @Test func monthAndYearBoundaries() {
        let cal = calendar("UTC")
        #expect(TrialTimeline(start: date(2026, 10, 28, in: cal), calendar: cal).chargeDate == date(2026, 11, 4, in: cal))
        #expect(TrialTimeline(start: date(2026, 12, 28, in: cal), calendar: cal).chargeDate == date(2027, 1, 4, in: cal))
        #expect(TrialTimeline(start: date(2028, 2, 25, in: cal), calendar: cal).chargeDate == date(2028, 3, 3, in: cal)) // leap year
    }

    @Test func daylightSavingDoesNotShiftTheLocalChargeDay() {
        // US spring-forward is 8 Mar 2026; the 7-day trial still ends on the same local clock time.
        let cal = calendar("America/New_York")
        let start = date(2026, 3, 5, 9, in: cal)
        let t = TrialTimeline(start: start, calendar: cal)
        #expect(t.chargeDate == date(2026, 3, 12, 9, in: cal))
        #expect(t.chargeDate.timeIntervalSince(start) == 7 * 86_400 - 3_600)
    }

    @Test func chargeDateTextIsExactAndLocalized() {
        let cal = calendar("UTC")
        let t = TrialTimeline(start: date(2026, 11, 1, in: cal), calendar: cal)
        #expect(t.chargeDateText(locale: Locale(identifier: "en_US")) == "November 8, 2026")
        #expect(t.chargeDateText(locale: Locale(identifier: "tr_TR")) == "8 Kasım 2026")
    }

    @Test func paywallDefaultsFollowTheHonestyRules() {
        let model = PaywallModel()
        #expect(model.selectedPlan == .lifetime)
        #expect(model.plans == [.lifetime, .annual, .monthly])
        #expect(model.sections.first == .whatStaysFree)
        #expect(model.sections.contains(.restore))
        #expect(Plan.allCases.allSatisfy { model.price(for: $0) == .placeholder })
        #expect(PriceDisplay.placeholder.text == "$XX" && PriceDisplay.placeholder.isPlaceholder)
        #expect(Set(model.freeFeatures) == FeatureGate.freeFeatures)
        #expect(Set(model.proFeatures) == FeatureGate.proFeatures)
    }

    @Test func realPricesReplacePlaceholders() {
        var model = PaywallModel(prices: [.lifetime: PriceDisplay(text: "$24.99")])
        #expect(model.price(for: .lifetime).text == "$24.99")
        #expect(!model.price(for: .lifetime).isPlaceholder)
        #expect(model.price(for: .annual) == .placeholder)
        model.select(.annual)
        #expect(model.selectedPlan == .annual)
    }

    @Test func trialTimelineOnlyForPlansWithATrial() {
        var model = PaywallModel()
        let cal = calendar("UTC")
        #expect(model.trialTimeline(startingAt: date(2026, 11, 1, in: cal), calendar: cal) == nil) // lifetime
        model.select(.annual)
        #expect(model.trialTimeline(startingAt: date(2026, 11, 1, in: cal), calendar: cal)?.steps.count == 3)
    }
}
