# ADR 0008: Pixel fidelity to the design wins over native stand-ins

- **Status:** Accepted (owner instruction, 2026-10-30)
- **Supersedes in part:** PRD §11.1 fonts (Q3), §11.2 stand-in table, PRD §7.1 minimum duration

## Context

The first Plan screen used MapKit, system fonts and a plain slider. The owner reviewed it against the Claude Design canvas and asked for the screens to match the design exactly ("gram şaşmadan"), including the trackpad-scrubbed duration ruler and the floating sidebar.

## Decision

1. **The canvas is the spec.** Where the PRD and the canvas disagree on how something looks or behaves, the canvas wins. Layout, sizes, colors, gradients, shadows, radii, type and motion are copied from the canvas source (`docs/design/export/`), not approximated.
2. **Bundled fonts.** Use the canvas fonts (Inter, Barlow Condensed, JetBrains Mono, Newsreader, all OFL) instead of SF Pro / SF Mono / New York.
3. **Own map rendering.** The canvas draws its own stylized map and globe from SVG geometry (`map-europe-*.svg`, `world-*.svg`, `meridian-world.js`). Reproduce them in SwiftUI `Canvas` from the same geometry instead of MapKit. MapKit stays an option for the Satellite style and the v2 window view only.
4. **Minimum flight duration is 30 minutes** (was 10). Quick chips and the ruler start at 30. The short-flight overhead rule of ADR 0003 stays in `FlightTiming` but is unreachable from the UI.
5. **Trackpad scrubbing.** The duration ruler is changed by two-finger scrolling (and drag, arrow keys) with detent haptics, as in the canvas.

## Consequences

- Every screen is verified by rendering the canvas artboard and the running app at the same size and comparing them (`Scripts/design-ref.sh`, `Scripts/compare.py`).
- More custom drawing code and bundled font files; fewer system-native behaviors for free (Dynamic Type, system map labels). Accessibility labels and Reduce Motion/Transparency still apply.
- Disputed-name labels (PRD §10.6) become the app's responsibility because the labels are drawn by us.
