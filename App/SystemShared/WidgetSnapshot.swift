import Foundation

/// What the widgets show. The app writes it (App/Meridian/Features/System/WidgetPublisher.swift) into the app
/// group; the widget extension reads it. Plain Codable, no app types.
struct WidgetSnapshot: Codable, Equatable {
    struct Live: Codable, Equatable {
        var originCode: String
        var destinationCode: String
        var destinationCity: String
        var flightNumber: String
        /// ETA while the clock runs; `nil` while paused.
        var eta: Date?
        var remainingSec: Double
        var progress: Double
        var kmToGo: Int
        var paused: Bool
    }
    struct NextCard: Codable, Equatable { var name: String; var percent: Int; var kmToGo: Int }
    struct Longest: Codable, Equatable { var originCode: String; var destinationCode: String; var km: Int; var durationText: String; var aroundEarth: Double }

    var live: Live?
    var nextCard = NextCard(name: "Meridian Gold", percent: 0, kmToGo: 20_000)
    var longest: Longest?
    /// Hours in flight, Monday to Sunday of the current week.
    var weekHours: [Double] = Array(repeating: 0, count: 7)
    var weekRange = ""
    var todayIndex = 0
    var streak = 0
    var updated = Date()

    static let groupID = "group.app.meridian.Meridian"
    private static let key = "widget.snapshot"

    static func load() -> WidgetSnapshot? {
        let d = UserDefaults(suiteName: groupID) ?? .standard
        return d.data(forKey: key).flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        (UserDefaults(suiteName: Self.groupID) ?? .standard).set(data, forKey: Self.key)
    }

    /// Commands a widget button leaves for the app (the pause button).
    static let commandKey = "widget.command"

    /// The artboard data of M04.
    static let preview = WidgetSnapshot(
        live: Live(originCode: "LHR", destinationCode: "CDG", destinationCity: "Paris", flightNumber: "MR 0142",
                   eta: nil, remainingSec: 18 * 60 + 54, progress: 0.55, kmToGo: 157, paused: false),
        nextCard: NextCard(name: "Meridian Gold", percent: 47, kmToGo: 7_978),
        longest: Longest(originCode: "LHR", destinationCode: "JFK", km: 5_540, durationText: "3 h 30 min", aroundEarth: 0.3),
        weekHours: [2.4, 3.1, 1.8, 4.2, 2.9, 1.1, 0.6], weekRange: "Mon 26 – Sun 1", todayIndex: 3, streak: 12)
}
