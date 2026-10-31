import SwiftUI

/// Harness routes (`--screen together-*`): the sidebar shell with the Together section at the canvas state.
@MainActor
enum TogetherRoutes {
    static func register() {
        func route(_ name: String, _ launch: TGLaunch) {
            ScreenRegistry.register(name, setup: { $0.section = .together; TogetherModel.launch = launch }) {
                AppShell(persona: ("Elif Kaya", 12022))
            }
        }
        route("together-friends", TGLaunch(screen: .friends, hoverFriend: "mert"))
        route("together-create", TGLaunch(screen: .create))
        route("together-lobby", TGLaunch(screen: .lobby, lobbyMs: 2300))
        route("together-inflight", TGLaunch(screen: .inflight, progress: 0.62, annaLanded: true))
        route("together-landing", TGLaunch(screen: .landing, progress: 1))
        route("together-public", TGLaunch(screen: .board))
    }
}
