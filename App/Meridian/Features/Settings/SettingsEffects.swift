import AppKit
import Foundation
import MeridianCore
import ServiceManagement
import UserNotifications

/// Side effects of settings that act on the system, not only on a stored value.
@MainActor
enum SettingsEffects {
    /// Applies theme and Dock visibility from the stored values. Called at launch and on change.
    static func applyAll() {
        applyTheme(SettingsKeys.theme.current)
        applyDock(SettingsKeys.showInDock.current)
    }

    /// `system | dark | light` becomes the app-wide `NSApp.appearance` (also reaches the Settings window).
    static func applyTheme(_ value: String) {
        switch value {
        case "dark": NSApp?.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp?.appearance = NSAppearance(named: .aqua)
        default: NSApp?.appearance = nil
        }
    }

    /// "Show in Dock" off = accessory app (menu bar only).
    static func applyDock(_ visible: Bool) {
        NSApp?.setActivationPolicy(visible ? .regular : .accessory)
    }

    // MARK: Login item

    static var launchAtLoginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func setLaunchAtLogin(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }

    // MARK: Language

    /// The app language applies at the next launch (`AppleLanguages`). "system" removes the override.
    static func applyLanguage(_ code: String) {
        if code == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }

    // MARK: Notifications

    /// Asks for permission the first time a notification type is switched on.
    static func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .timeSensitive]) { _, _ in }
    }

    // MARK: Map cache

    static var mapCacheBytes: Int { URLCache.shared.currentDiskUsage }

    static func clearMapCache() { URLCache.shared.removeAllCachedResponses() }
}

/// Export of the flight log (Settings > Data and privacy > Export my flights).
enum FlightExport {
    enum Format: String, CaseIterable { case csv, json
        var fileExtension: String { rawValue }
        var title: String { self == .csv ? "CSV" : "JSON" }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func data(for flights: [Flight], format: Format) -> Data {
        switch format {
        case .csv: Data(csv(flights).utf8)
        case .json: json(flights)
        }
    }

    static let columns = ["id", "origin", "destination", "scenario", "topic", "notes", "status", "started_at", "ended_at",
                          "planned_minutes", "route_km", "credited_km"]

    static func csv(_ flights: [Flight]) -> String {
        var lines = [columns.joined(separator: ",")]
        for f in flights {
            let fields: [String] = [
                f.id.uuidString, f.originIata, f.destinationIata ?? "", f.scenarioID, f.topic, f.notes, f.status.rawValue,
                f.startedAt.map(isoFormatter.string(from:)) ?? "", f.endedAt.map(isoFormatter.string(from:)) ?? "",
                f.durationSec.map { String(Int($0 / 60)) } ?? "", String(format: "%.1f", f.routeDistanceKm), String(format: "%.1f", f.creditedKm),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func json(_ flights: [Flight]) -> Data {
        let rows: [[String: Any]] = flights.map { f in
            var row: [String: Any] = [
                "id": f.id.uuidString, "origin": f.originIata, "scenario": f.scenarioID, "topic": f.topic, "notes": f.notes,
                "status": f.status.rawValue, "route_km": (f.routeDistanceKm * 10).rounded() / 10, "credited_km": (f.creditedKm * 10).rounded() / 10,
            ]
            if let d = f.destinationIata { row["destination"] = d }
            if let s = f.startedAt { row["started_at"] = isoFormatter.string(from: s) }
            if let e = f.endedAt { row["ended_at"] = isoFormatter.string(from: e) }
            if let d = f.durationSec { row["planned_minutes"] = Int(d / 60) }
            return row
        }
        let object: [String: Any] = ["app": "Meridian", "exported_at": isoFormatter.string(from: .now), "flights": rows]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
    }

    /// Shows a save panel and writes the file. Returns the saved URL, or nil if cancelled/failed.
    @MainActor
    static func save(_ flights: [Flight], format: Format) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "meridian-flights.\(format.fileExtension)"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do { try data(for: flights, format: format).write(to: url, options: .atomic); return url } catch { return nil }
    }
}
