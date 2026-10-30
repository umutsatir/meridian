import Foundation

public struct AppInfo: Sendable, Hashable, Codable {
    public var bundleID: String
    public var name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// Reports the app that just came to the front. The app target feeds these
/// into ``FocusEnforcer``; tests use ``ManualFrontmostSource``.
public protocol FrontmostAppSource: Sendable {
    var changes: AsyncStream<AppInfo> { get }
}

/// Test double: push apps by hand.
public struct ManualFrontmostSource: FrontmostAppSource {
    public let changes: AsyncStream<AppInfo>
    private let continuation: AsyncStream<AppInfo>.Continuation

    public init() {
        (changes, continuation) = AsyncStream.makeStream(of: AppInfo.self)
    }

    public func activate(_ app: AppInfo) { continuation.yield(app) }
    public func finish() { continuation.finish() }
}

#if os(macOS)
import AppKit

/// Frontmost-app detection through `NSWorkspace` activation notifications.
/// Needs no Accessibility permission (ADR 0006). Emits the current frontmost
/// app first, then every activation.
public struct NSWorkspaceFrontmostSource: FrontmostAppSource {
    public init() {}

    public var changes: AsyncStream<AppInfo> {
        AsyncStream { continuation in
            if let app = NSWorkspace.shared.frontmostApplication, let info = Self.info(for: app) {
                continuation.yield(info)
            }
            let token = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let info = Self.info(for: app) else { return }
                continuation.yield(info)
            }
            let box = ObserverBox(token)
            continuation.onTermination = { _ in
                NSWorkspace.shared.notificationCenter.removeObserver(box.token)
            }
        }
    }

    private static func info(for app: NSRunningApplication) -> AppInfo? {
        guard let id = app.bundleIdentifier else { return nil }
        return AppInfo(bundleID: id, name: app.localizedName ?? id)
    }
}

private final class ObserverBox: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
}
#endif
