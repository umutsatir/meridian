import Foundation
import MeridianCore
import WidgetKit

/// Builds the widget snapshot from the model and hands it to the widget extension.
@MainActor
enum WidgetPublisher {
    private static var lastSnapshot: WidgetSnapshot?

    static func publish(model: AppModel, info: SystemFlightInfo, flight: Flight?, now: Date) {
        var s = WidgetSnapshot()
        let km = model.totalKm
        // Next card: the first tier above the current total.
        if let next = MembershipTier.allCases.first(where: { $0.thresholdKm > km }) {
            let prev = MembershipTier.tier(forKm: km).thresholdKm
            s.nextCard = .init(name: Self.title(next), percent: Int(((km - prev) / (next.thresholdKm - prev) * 100).rounded()),
                               kmToGo: Int((next.thresholdKm - km).rounded()))
        } else {
            s.nextCard = .init(name: Self.title(.obsidian), percent: 100, kmToGo: 0)
        }
        if let longest = model.walletFlights.max(by: { $0.routeDistanceKm < $1.routeDistanceKm }), let dest = longest.destinationIata {
            let min = Int(((longest.durationSec ?? 0) / 60).rounded())
            s.longest = .init(originCode: longest.originIata, destinationCode: dest, km: Int(longest.routeDistanceKm.rounded()),
                              durationText: min >= 60 ? "\(min / 60) h \(min % 60) min" : "\(min) min",
                              aroundEarth: (longest.routeDistanceKm / Geo.equatorKm * 10).rounded() / 10)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        if let week = cal.dateInterval(of: .weekOfYear, for: now) {
            var hours = Array(repeating: 0.0, count: 7)
            for f in model.walletFlights {
                guard let ended = f.endedAt, week.contains(ended) else { continue }
                let day = cal.dateComponents([.day], from: week.start, to: cal.startOfDay(for: ended)).day ?? 0
                if (0..<7).contains(day) { hours[day] += (f.finalFocusedSec ?? f.elapsedSec(at: ended)) / 3600 }
            }
            s.weekHours = hours
            s.todayIndex = cal.dateComponents([.day], from: week.start, to: cal.startOfDay(for: now)).day ?? 0
            let f = DateFormatter(); f.dateFormat = "EEE d"
            s.weekRange = "\(f.string(from: week.start)) – \(f.string(from: week.end.addingTimeInterval(-1)))"
        }
        s.streak = model.streak
        if let flight, info.kind == .flight || info.kind == .last {
            s.live = .init(originCode: info.originCode, destinationCode: info.destinationCode, destinationCity: info.destinationCity,
                           flightNumber: info.flightNumber, eta: flight.isHeld ? nil : info.eta, remainingSec: info.timeSec,
                           progress: info.progress, kmToGo: info.distanceToGoKm, paused: info.paused)
        }
        s.updated = now
        var compare = s; compare.updated = .distantPast
        var previous = lastSnapshot; previous?.updated = .distantPast
        guard compare != previous else { return }
        lastSnapshot = s
        s.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func title(_ t: MembershipTier) -> String {
        switch t {
        case .departure: "Departure"
        case .cruise: "Cruise"
        case .jetstream: "Jetstream"
        case .meridianGold: "Meridian Gold"
        case .equator: "Equator"
        case .obsidian: "Obsidian"
        }
    }
}
