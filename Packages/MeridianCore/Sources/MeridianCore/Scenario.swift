import Foundation

public struct Scenario: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var name: String
    public var symbol: String
    /// Hex color, e.g. `#7AA2FF`.
    public var colorHex: String
    public var isCustom: Bool

    public init(id: String, name: String, symbol: String, colorHex: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.isCustom = isCustom
    }

    public static let defaults: [Scenario] = [
        .init(id: "study", name: "Study", symbol: "book", colorHex: "#7AA2FF"),
        .init(id: "work", name: "Work", symbol: "briefcase", colorHex: "#FFB86B"),
        .init(id: "read", name: "Read", symbol: "text.book.closed", colorHex: "#7ADDB2"),
        .init(id: "create", name: "Create", symbol: "paintbrush", colorHex: "#FF8FB1"),
        .init(id: "code", name: "Code", symbol: "chevron.left.forwardslash.chevron.right", colorHex: "#B49CFF"),
        .init(id: "meditate", name: "Meditate", symbol: "leaf", colorHex: "#8EE3E8"),
        .init(id: "fitness", name: "Fitness", symbol: "figure.run", colorHex: "#FF9B7A"),
        .init(id: "other", name: "Other", symbol: "ellipsis", colorHex: "#C7CCDA"),
    ]
}
