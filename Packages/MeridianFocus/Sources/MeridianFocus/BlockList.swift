import Foundation

public enum BlockMode: String, Sendable, Codable, CaseIterable {
    case off
    /// A quiet toast when a listed app comes to the front.
    case nudge
    /// Our own overlay window (see ``Intervention/overlay(_:)``).
    case strictOverlay
}

/// Apps and websites the user wants to stay away from during a flight (PRD BLK-2).
///
/// Only `apps` are enforced in v1: the frontmost app is known from `NSWorkspace`
/// without the Accessibility permission (ADR 0006), but the page a browser shows
/// is not. `domains` are stored so the list is complete when website blocking
/// becomes possible.
public struct BlockList: Sendable, Hashable, Codable {
    public var apps: Set<String>
    public var domains: Set<String>

    public init(apps: Set<String> = [], domains: Set<String> = []) {
        self.apps = apps
        self.domains = Set(domains.map(Self.normalize))
    }

    public func blocksApp(bundleID: String) -> Bool { apps.contains(bundleID) }

    /// Matches the domain itself and any subdomain (`m.youtube.com` for `youtube.com`).
    public func blocksDomain(_ host: String) -> Bool {
        let h = Self.normalize(host)
        return domains.contains { h == $0 || h.hasSuffix("." + $0) }
    }

    public func union(_ other: BlockList) -> BlockList {
        BlockList(apps: apps.union(other.apps), domains: domains.union(other.domains))
    }

    private static func normalize(_ host: String) -> String {
        var h = host.lowercased()
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }
}

public enum BlockPreset: String, Sendable, Codable, CaseIterable {
    case social, video, games, news

    public var list: BlockList {
        switch self {
        case .social:
            BlockList(
                apps: ["com.hnc.Discord", "ru.keepcoder.Telegram", "net.whatsapp.WhatsApp"],
                domains: ["x.com", "twitter.com", "instagram.com", "facebook.com", "tiktok.com", "reddit.com"]
            )
        case .video:
            BlockList(
                apps: ["com.apple.TV"],
                domains: ["youtube.com", "netflix.com", "twitch.tv", "primevideo.com", "disneyplus.com"]
            )
        case .games:
            BlockList(
                apps: ["com.valvesoftware.steam", "com.epicgames.EpicGamesLauncher"],
                domains: ["store.steampowered.com", "epicgames.com"]
            )
        case .news:
            BlockList(
                apps: ["com.apple.news"],
                domains: ["news.ycombinator.com", "nytimes.com", "bbc.com", "cnn.com", "hurriyet.com.tr"]
            )
        }
    }
}
