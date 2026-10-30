import Foundation
import MeridianCore

/// ONB-2: where the user probably is. No permission is needed: the time zone of the Mac is enough
/// for a good first guess, and the user can always change it (search, or Settings later).
/// TODO(onboarding): optional CoreLocation "Use my location" (coarse) once the location entitlement
/// and usage string are added to the app target; the flow works without it.
struct DetectedPlace: Equatable {
    var city: String
    var center: Coordinate
    /// Airports to offer, in display order.
    var airports: [String]
}

enum AirportDetection {
    private struct Metro {
        let city: String
        let lat: Double, lon: Double
        let airports: [String]
    }

    /// Time zone id to metro area (centre of the city and its airports, main one first).
    private static let metros: [String: Metro] = [
        "Europe/London": .init(city: "London", lat: 51.5074, lon: -0.1278, airports: ["LHR", "LGW", "STN", "LCY", "LTN"]),
        "Europe/Istanbul": .init(city: "Istanbul", lat: 41.0082, lon: 28.9784, airports: ["IST", "SAW"]),
        "Europe/Paris": .init(city: "Paris", lat: 48.8566, lon: 2.3522, airports: ["CDG", "ORY", "BVA"]),
        "Europe/Berlin": .init(city: "Berlin", lat: 52.52, lon: 13.405, airports: ["BER"]),
        "Europe/Madrid": .init(city: "Madrid", lat: 40.4168, lon: -3.7038, airports: ["MAD"]),
        "Europe/Rome": .init(city: "Rome", lat: 41.9028, lon: 12.4964, airports: ["FCO", "CIA"]),
        "Europe/Amsterdam": .init(city: "Amsterdam", lat: 52.3676, lon: 4.9041, airports: ["AMS", "RTM"]),
        "Europe/Dublin": .init(city: "Dublin", lat: 53.3498, lon: -6.2603, airports: ["DUB"]),
        "Europe/Lisbon": .init(city: "Lisbon", lat: 38.7223, lon: -9.1393, airports: ["LIS"]),
        "Europe/Zurich": .init(city: "Zurich", lat: 47.3769, lon: 8.5417, airports: ["ZRH"]),
        "Europe/Vienna": .init(city: "Vienna", lat: 48.2082, lon: 16.3738, airports: ["VIE"]),
        "America/New_York": .init(city: "New York", lat: 40.7128, lon: -74.006, airports: ["JFK", "EWR", "LGA"]),
        "America/Chicago": .init(city: "Chicago", lat: 41.8781, lon: -87.6298, airports: ["ORD", "MDW"]),
        "America/Los_Angeles": .init(city: "Los Angeles", lat: 34.0522, lon: -118.2437, airports: ["LAX", "BUR", "SNA"]),
        "America/Toronto": .init(city: "Toronto", lat: 43.6532, lon: -79.3832, airports: ["YYZ"]),
        "Asia/Tokyo": .init(city: "Tokyo", lat: 35.6762, lon: 139.6503, airports: ["HND", "NRT"]),
        "Asia/Dubai": .init(city: "Dubai", lat: 25.2048, lon: 55.2708, airports: ["DXB", "DWC"]),
        "Asia/Singapore": .init(city: "Singapore", lat: 1.3521, lon: 103.8198, airports: ["SIN"]),
        "Australia/Sydney": .init(city: "Sydney", lat: -33.8688, lon: 151.2093, airports: ["SYD"]),
    ]

    static let fallback = "Europe/London"

    /// The guess for this Mac. Falls back to London when nothing matches (the design's example).
    static func detect(index: AirportIndex, timeZone: TimeZone = .current) -> DetectedPlace {
        place(for: timeZone.identifier, index: index) ?? place(for: fallback, index: index)!
    }

    static func place(for timeZoneID: String, index: AirportIndex) -> DetectedPlace? {
        guard let m = metros[timeZoneID] else { return nil }
        let codes = m.airports.filter { index.airport(iata: $0) != nil }
        guard !codes.isEmpty else { return nil }
        return DetectedPlace(city: index.airport(iata: codes[0])?.city ?? m.city,
                             center: Coordinate(latitude: m.lat, longitude: m.lon), airports: codes)
    }

    /// "24 km" style distance from the detected centre.
    static func distanceLabel(from center: Coordinate, to airport: Airport) -> String {
        let km = Geo.distanceKm(from: center, to: airport.coordinate)
        return "\(Int(km.rounded())) km"
    }
}
