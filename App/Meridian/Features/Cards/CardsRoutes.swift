import MeridianUI
import SwiftUI

/// DEBUG routes of the Cards and Passport screens. The canvas persona (K.me) is passed as a fixture; the
/// real app reads `AppModel`.
extension ScreenRegistry {
    static func registerCardsPassportRoutes() {
        let persona: (String, Double) = ("Elif Kaya", 12022)
        register("cards", setup: { $0.section = .cards }) {
            AppShell(persona: persona).environment(\.cardsFixture, .fixture)
        }
        register("cards-light", setup: { $0.section = .cards }) {
            AppShell(persona: persona).environment(\.cardsFixture, .fixture).preferredColorScheme(.light)
        }
        register("unlock", setup: {
            $0.section = .cards
            CardUnlockPresenter.shared.presentFixture(tier: .gold, atMs: 2900, content: .fixture)
        }) {
            AppShell(persona: persona).environment(\.cardsFixture, .fixture)
        }
        func passport(_ start: PassportStart) -> some View {
            AppShell(persona: persona)
                .environment(\.passportFixture, .fixture)
                .environment(\.passportStart, start)
        }
        register("passport", setup: { $0.section = .passport }) { passport(PassportStart(animIndex: 11)) }
        register("passport-filtered", setup: { $0.section = .passport }) { passport(PassportStart(year: "2025", scenario: "code")) }
        register("passport-spread2", setup: { $0.section = .passport }) { passport(PassportStart(spread: 1)) }
    }
}
