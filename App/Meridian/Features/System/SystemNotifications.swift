import AppKit
import MeridianCore
import MeridianCruise
import UserNotifications

/// M05: four calm banners through `UNUserNotificationCenter`. Every kind can be switched off in
/// `SystemSettings`. Only the landing heads-up is Time Sensitive; nothing is shown while Meridian is frontmost.
@MainActor
final class SystemNotifications: NSObject, UNUserNotificationCenterDelegate {
    nonisolated enum Category {
        static let boarding = "BOARDING", gate = "GATE", landing = "LANDING", together = "TOGETHER"
    }
    nonisolated enum Action {
        static let checkIn = "CHECK_IN", snooze = "SNOOZE", chooseSeat = "CHOOSE_SEAT", notNow = "NOT_NOW"
        static let returnToFocus = "RETURN_TO_FOCUS", addFive = "ADD_5", openLobby = "OPEN_LOBBY", dismiss = "DISMISS"
    }

    private var settings: SystemSettings?
    private var openApp: (() -> Void)?
    private var center: UNUserNotificationCenter? {
        // Not available when the binary runs outside an app bundle (tests).
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func configure(settings: SystemSettings, openApp: @escaping () -> Void) {
        self.settings = settings
        self.openApp = openApp
        guard let center else { return }
        center.delegate = self
        func action(_ id: String, _ title: String) -> UNNotificationAction { UNNotificationAction(identifier: id, title: title, options: [.foreground]) }
        func quiet(_ id: String, _ title: String) -> UNNotificationAction { UNNotificationAction(identifier: id, title: title, options: []) }
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.boarding, actions: [action(Action.checkIn, "Check in"), quiet(Action.snooze, "Snooze 2 min")], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.gate, actions: [action(Action.chooseSeat, "Choose seat"), quiet(Action.notNow, "Not now")], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.landing, actions: [action(Action.returnToFocus, "Return to focus"), quiet(Action.addFive, "Add 5 min")], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.together, actions: [action(Action.openLobby, "Open lobby"), quiet(Action.dismiss, "Dismiss")], intentIdentifiers: []),
        ])
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: Kinds

    func boardingCall(flightNumber: String, gate: String, flightID: UUID) {
        guard settings?.notifyBoarding == true else { return }
        post(id: "boarding-\(flightID)", title: "Boarding · \(flightNumber)", body: "Gate \(gate) is open. Doors close in 3 minutes.",
             category: Category.boarding, thread: flightID, after: 1)
    }

    func gateOpens(at date: Date, destination: String, time: String, flightID: UUID) {
        guard settings?.notifyGate == true, date > .now else { return }
        post(id: "gate-\(flightID)", title: "Gate opens in 5 min", body: "Your \(time) flight to \(destination). Pick a seat while you wait.",
             category: Category.gate, thread: flightID, after: date.timeIntervalSinceNow)
    }

    /// Scheduled for a backgrounded app at T-5 minutes (PRD LND-1).
    func scheduleLanding(for flight: Flight) {
        guard settings?.notifyLanding == true, let date = LandingAlert.notificationDate(for: flight, at: .now) else { return }
        post(id: "landing-\(flight.id)", title: "Prepare for landing", body: "Cabin crew, prepare for landing. 5 minutes to go.",
             category: Category.landing, thread: flight.id, after: date.timeIntervalSinceNow, timeSensitive: true)
    }

    func cancelLanding(flightID: UUID) {
        center?.removePendingNotificationRequests(withIdentifiers: ["landing-\(flightID)"])
    }

    func landingHeadsUp(minutes: Int, flight: Flight) {
        guard settings?.notifyLanding == true else { return }
        post(id: "landing-now-\(flight.id)", title: "Prepare for landing", body: "Cabin crew, prepare for landing. \(minutes) minutes to go.",
             category: Category.landing, thread: flight.id, after: 1, timeSensitive: true)
    }

    func friendJoined(name: String, aboard: Int, of total: Int, route: String, flightID: UUID) {
        guard settings?.notifyFriend == true else { return }
        post(id: "friend-\(UUID())", title: "\(name) joined your flight", body: "\(route) · \(aboard) of \(total) aboard",
             category: Category.together, thread: flightID, after: 1)
    }

    private func post(id: String, title: String, body: String, category: String, thread: UUID, after: TimeInterval, timeSensitive: Bool = false) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.threadIdentifier = thread.uuidString
        content.sound = .default
        if timeSensitive { content.interruptionLevel = .timeSensitive }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, after), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Delegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The in-app toast replaces the banner while Meridian is frontmost.
        await MainActor.run { NSApp.isActive } ? [] : [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.actionIdentifier
        guard id != Action.snooze, id != Action.notNow, id != Action.dismiss, id != Action.addFive else { return }
        await MainActor.run { self.openApp?() }
    }
}
