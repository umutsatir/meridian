# Design

## Source of truth

The design lives in a Claude Design canvas, **"Meridian — Design System"** (179 artboards):

<https://claude.ai/artifact/SLMJeFuvyjfXmkohJfjiAf>

The canvas is private to the owner. Contributors and sessions that cannot open it should ask the owner for an export; this folder is where an offline export would live (`docs/design/export/`, not yet added).

## What is in the canvas

| Group | Artboards | Contents |
|---|---|---|
| 01 Foundations | F1–F3 | Color (Night Cabin dark, Daybreak light), type, spacing, radii, icons, glass and motion tokens |
| 02 Components | C01–C12 | Boarding pass, print animation, tear-off, membership cards, destination picker, seat and window, flight HUD, map styles, passport and stamps, stats and sound, social, UI kit |
| 04a Onboarding | S01–S07 | Welcome, home airport, scenarios, map style, permission warm-ups, account, ready |
| 04b Plan, check in, board | S10–S15 | Plan, search and surprise, seat and scenario, printing, tear, gate, take-off |
| 04c Collection | S30–S37 | Wallet (four color views, stack), ticket detail, cards, unlock, passport, world map, stats, year in flight |
| 04d In flight and landing | S16–S23 | Cruise map (four styles), window, dashboard, pause and land early, meal break, descent, landing, wallet-in |
| 04e Together | S40–S45 | Friends, shared flight, lobby, in-flight passengers, group landing, public flights |
| 04f Settings and Pro | S50–S54 | Settings, soft blocking, sounds, paywall, states and errors |
| 05 System surfaces | M01–M06 | Menu bar, floating mini map, seat-back TV, widgets, notifications, app icon and Dock |
| 06 Redlines | R01–R05 | Dimensions, paddings, radii, type styles and tokens for the key components |
| 07 Motion and sound | T01–T03, A01 | Sixteen signature motions with timelines, sound recipes |
| 08 Prototypes | P1–P6 | Live prototypes (ticket ritual, card tilt, planning, in-flight, together, mini map) |
| 09 Rationale | Z01 | Where the design departs from the brief, stand-ins to replace natively, open questions |

## Rules for implementers

- Use only tokens defined in F1–F3. A new value is added to the token list first.
- The canvas uses stand-in fonts (Inter, Barlow Condensed, JetBrains Mono, Newsreader). Native uses SF Pro, SF Pro Condensed, SF Mono and New York.
- The canvas is a web mock. Stand-ins for native effects (glass, card bend, stamp ink, satellite, globe) are listed in Z01 and PRD §11.2.
- Redlines R01–R05 give exact sizes for the boarding pass, membership card, ticket printer, mini window and menu bar popover.

## Competitor reference images

The research used marketing screenshots of a competing app to understand flows. They are **not** stored in this repository. Meridian's visual identity, names, art and sound are original.
