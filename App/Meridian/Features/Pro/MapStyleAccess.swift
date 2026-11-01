import MeridianMaps
import MeridianPro

/// Who may use which map style. Satellite is a Pro feature (`FeatureGate.mapSatellite`, PRD §9.13).
enum MapStyleAccess {
    /// TODO(pro): there is no Pro purchase yet, and the owner wants to see Satellite now, so everyone gets it.
    /// Set this to `false` when the StoreKit purchase ships: the quiet "Satellite is part of Meridian Pro" hint
    /// (onboarding S04) and the Pro lock then apply again. See docs/design/ui-notes.md.
    static let satelliteUnlockedForNow = true

    @MainActor static func isUnlocked(_ style: MapStyle) -> Bool {
        guard style == .satellite else { return true }
        return satelliteUnlockedForNow || FeatureGate.isAvailable(.mapSatellite, for: ProModel.shared.entitlement)
    }

    /// The style to actually draw: a locked style falls back to Terra.
    @MainActor static func resolved(_ style: MapStyle) -> MapStyle { isUnlocked(style) ? style : .terra }
}
