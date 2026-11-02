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
        // Pointer simulation (`--sim "m 530,400; snap a; c 860,400; w 1; snap b"`, see Debug/CardSim.swift).
        register("cards-sim", setup: { $0.section = .cards }) {
            CardSimHost { AppShell(persona: persona).environment(\.cardsFixture, .fixture) }
        }
        // A lone live hero card (own pointer tracking) at (400, 200) in a 1280 x 800 window, for `--sim`.
        register("card-hover-sim") {
            CardSimHost {
                ZStack(alignment: .topLeading) {
                    Color(white: 0.08)
                    MembershipCardView(tier: .cruise, size: .hero, live: true).offset(x: 400, y: 200)
                }
            }
        }
        register("pass-hover-sim") {
            CardSimHost {
                ZStack(alignment: .topLeading) {
                    Color(white: 0.08)
                    BoardingPassView(.sample, state: .printed, live: true).offset(x: 460, y: 100)
                }
            }
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
