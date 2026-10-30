# MeridianUI notes

`Packages/MeridianUI` holds the design tokens (PRD Appendix B) and first components. It does not depend on `MeridianCore`.

Assumptions made because the canvas (F1–F3, R01–R05) is not available offline; check them against the canvas:

- Amber, paper and ink are the same in light and dark (physical materials). The PRD lists no light-theme values for them.
- Label on a filled accent-1 button: `bg-0` in dark, `bg-2` in light (`MRPalette.onAccent`).
- Spring parameters in `MRMotion` and the boarding pass size (430 + 128 × 208 pt) are provisional.
- Cabin foil gradients in `BoardingPassCabin.foilHexes` are placeholders.
- `Font` sizes are fixed; macOS has no Dynamic Type, so the "130% type scale" rule needs a separate mechanism.
