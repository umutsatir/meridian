import SwiftUI

/// Pins an interaction state on the controls below (the canvas `.is-hover`, `.is-pressed`, `.is-focus` classes), so
/// galleries and the C12 UI-kit screen can draw every state without a pointer. Never set by the app itself.
public enum MRForcedState: Sendable { case none, hover, pressed, focus }

private struct MRForcedStateKey: EnvironmentKey { static let defaultValue: MRForcedState = .none }

public extension EnvironmentValues {
    var mrForcedState: MRForcedState {
        get { self[MRForcedStateKey.self] }
        set { self[MRForcedStateKey.self] = newValue }
    }
}

public extension View {
    /// Draws descendants' controls as if the pointer / keyboard were in `state`.
    func mrForceState(_ state: MRForcedState) -> some View { environment(\.mrForcedState, state) }
}
