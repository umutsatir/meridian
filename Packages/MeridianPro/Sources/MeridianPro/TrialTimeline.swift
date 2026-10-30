import Foundation

/// The dates shown on the paywall before anyone is charged (PRD §9.13):
/// Today, a reminder on Day 5, the charge on Day 7.
public struct TrialTimeline: Sendable, Hashable {
    public static let trialDays = 7
    public static let reminderDay = 5

    public struct Step: Sendable, Hashable {
        public enum Kind: String, Sendable { case today, reminder, charge }
        public let kind: Kind
        public let day: Int
        public let date: Date
    }

    public let start: Date
    public let steps: [Step]
    public let timeZone: TimeZone

    /// Calendar days, not 24-hour blocks, so daylight-saving changes do not
    /// move the charge to a different local date.
    public init(start: Date, calendar: Calendar = .current) {
        self.start = start
        self.timeZone = calendar.timeZone
        func date(plus days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: start) ?? start }
        steps = [
            Step(kind: .today, day: 0, date: start),
            Step(kind: .reminder, day: Self.reminderDay, date: date(plus: Self.reminderDay)),
            Step(kind: .charge, day: Self.trialDays, date: date(plus: Self.trialDays)),
        ]
    }

    public var chargeDate: Date { steps[2].date }
    public var reminderDate: Date { steps[1].date }

    /// Exact, unabbreviated charge date for the paywall, e.g. "6 November 2026".
    public func chargeDateText(locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted, locale: locale, timeZone: timeZone)
        style.calendar = Calendar(identifier: .gregorian)
        return chargeDate.formatted(style)
    }
}
