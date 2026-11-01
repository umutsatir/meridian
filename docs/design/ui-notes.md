# MeridianUI notes

`Packages/MeridianUI` holds the design tokens (PRD Appendix B) and first components. It does not depend on `MeridianCore`.

Assumptions made because the canvas (F1–F3, R01–R05) is not available offline; check them against the canvas:

- Amber, paper and ink are the same in light and dark (physical materials). The PRD lists no light-theme values for them.
- Label on a filled accent-1 button: `bg-0` in dark, `bg-2` in light (`MRPalette.onAccent`).
- Spring parameters in `MRMotion` and the boarding pass size (430 + 128 × 208 pt) are provisional.
- Cabin foil gradients in `BoardingPassCabin.foilHexes` are placeholders.
- `Font` sizes are fixed; macOS has no Dynamic Type, so the "130% type scale" rule needs a separate mechanism.

## Apple Maps surfaces (phase-d/satellite)

- **Engine.** All map surfaces go through `MapSurface` (`Packages/MeridianMaps/AppleMapView.swift`). Settings > Maps > "Map engine": Apple Maps (default) or Illustrated (the canvas drawing of ADR 0008). "Home globe": Realistic (MapKit `.imagery(elevation: .realistic)` globe, `SatelliteGlobeView`) or Illustrated. Launch argument `--map-engine illustrated|apple` overrides the setting (used by the design comparison routes; compare S10B etc. with `--map-engine illustrated`).
- **Styles.** Terra = muted standard map in the dark appearance, Mono = muted standard with the colour removed, Standard = standard map, Satellite = realistic imagery.
- **Overlays stay aligned** because `AppleMapView` fits the exact map rect of the design camera (Web Mercator, same as `EuropeProjection`); range ring, tags, route, plane and home marker are still our SwiftUI layers over a flat top-down map, not MapKit `Annotation`s (except the Home globe marker, which is a real `Annotation`). Camera moves use MapKit's own animation, so a 560 ms overlay move and the map move are close but not identical.
- **Satellite access.** `MapStyleAccess.satelliteUnlockedForNow = true` makes Satellite free for everyone until the Pro purchase exists. TODO: set it to `false` when StoreKit ships; the Pro lock and the quiet "Satellite is part of Meridian Pro" hint then apply (`FeatureGate.mapSatellite`).
- **Offline.** `MapHealth` (NWPathMonitor plus MapKit load-failure callbacks) switches surfaces to the illustrated map and shows the S54 text. `--map-offline` forces it. The app needs `com.apple.security.network.client` (build setting `ENABLE_OUTGOING_NETWORK_CONNECTIONS`).
- **Known limitation (PRD §10.6, Q5).** Apple Maps draws its own labels and borders: Meridian cannot control disputed names or dashed borders, nor hide labels (they can collide with our airport tags). The "both names" and borders settings only affect the Illustrated engine. Decide whether Illustrated must stay the default where that policy is required.
- **Not converted:** World/Explore globe (left to `phase-d/map-zoom`), take-off, landing, seat TV, ritual and Together maps still use the illustrated engine.
