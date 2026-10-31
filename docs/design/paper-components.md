# Paper components (MeridianUI)

All in `Packages/MeridianUI/Sources/MeridianUI/Paper/` (plus `Components/TearState.swift`). Measures are the canvas' (Ticket, Card, Stamp, SplitFlap, Ritual, R01-R03). `import MeridianUI`.

## BoardingPassView (360 x 600, `scale` multiplies the frame)

```swift
BoardingPassView(model, state: .printed, side: .front, scale: 1, flat: false, live: false, hoverPose: false)
```
- `BoardingPassModel(originCode:originCity:destinationCode:destinationCity:originCoordinate:destinationCoordinate:flightNumber:gate:seat:durationMinutes:distanceKm:cabin:scenario:topic:dateText:boardingTime:passengerName:notes:landTime:flownMinutes:groupInitials:colorBy:continent:month:seed:)`. `seed` defaults to `hash(from + to + flight)` (same FNV-1a as the canvas), so the torn edge and barcode are the canvas'. `cabin` defaults from the duration (`BoardingPassCabin.cabin(forMinutes:)`). Coordinates (lat/lon) drive the dotted route watermark; without them the watermark is omitted. `BoardingPassModel.sample` = LHR-CDG MR 0142.
- `state`: `.printed .printing(0...1) .torn .boarding .inflight(0...1) .landed .diverted .group .locked`. Torn-shaped states are 452 pt tall.
- `side`: `.front`, `.back` (map + arc, notes, stats, Edit / Share / Delete).
- `colorBy` on the model: `.scenario .class .continent .month` (band, underline, 7 pt foil in Class).
- `live: true`: wallet-tile hover (lift 8, tilt up to 6 degrees, perspective 900, snappy spring). `hoverPose: true` draws the static hover pose.
- Light and dark: paper is a material, identical in both; only the surrounding background changes. `.locked` uses the theme tokens.
- Reduce Motion: no tilt, no BOARDING pulse.

## Printing (C02 / T01 / R03)

```swift
let clock = TicketPrintClock()
clock.onStep = { i in /* 0...13: stepper chirp + haptic tick */ }
clock.onSettle = { /* 1800 ms: soft tick, heavier haptic */ }
clock.onReady = { /* 2100 ms: show "Tear here" */ }
TicketPrintAnimation(model: model, clock: clock, stage: CGSize(width: 1280, height: 800), centerX: nil, slotTop: 56)
```
- `clock.start(reduceMotion:)` (also auto-started on appear), `clock.skip()` (Space / Return). Reduce Motion: no printer, 200 ms cross-fade, one `onSettle`/`onReady`, no steps.
- `TicketPrintTimeline.frame(atMs:seed:)` is the pure timeline (14 x 114 ms: 84 ms easeOutCubic + 30 ms hold from 200 ms; settle 1800-2100: 6 pt sine, +-1.5 degrees; veil fades 1800-2060). `TicketPrinterStage(model:frame:...)` draws any frame (scrubbing, previews). The stage is transparent: put the dimmed, blurred map under it.

## Tearing (C03)

```swift
let tear = TicketTearModel()
tear.onBegin = { }                 // pointer down: start rip noise (gated at 0)
tear.onTick = { n in }             // every 6 %: light haptic
tear.onVelocity = { v in }         // 0...1 smoothed pointer speed, 0 when still (rip volume / band-pass)
tear.onFinish = { }                // >= 72 %: rip accelerates
tear.onRelease = { p in }          // released below 72 %: partial tear stays
tear.onTorn = { }                  // stub off: heavy release tick
tear.onFlyEnd = { }                // 150 Hz thud, +1 on the Wallet
TearGesture(model: model, tear: tear, flyTarget: CGPoint(x: -142, y: -300))   // flyTarget in pass-local points
```
- Drag on the stub (y >= 450): progress = pull / 360 with easeInCubic resistance below 10 %; the tear front follows the pointer (can retreat); particles (3-6 per burst, ballistic); stub pivots about the front up to 25 degrees (`25 * (1 - (1-p)^1.6)`); 72 % auto-finishes in 260 ms (ease-in quad), then a 720 ms smoothstep fly with 320 degree spin, scale 1 to 0.1.
- Keyboard: Space / Return (focusable) run the 650 ms button tear. VoiceOver: custom action "Tear off the stub". `tear.tearWithButton(reduceMotion:)` for the visible Tear button. Reduce Motion: no rotation or fly, quick fade.
- `TearState` is the pure logic (`drag(to:)` returns haptic ticks, `release()`, `complete()`, `smoothedVelocity`).
- Not included: the "Tear here" glass pill, the toast, the wallet badge (screen-level).

## MembershipCardView (R02, C04)

```swift
MembershipCardView(tier: .gold, size: .list /* 340x214 */ or .hero /* 480x302 */, locked: false,
                   info: MembershipCardInfo(...), live: true, pose: nil, flipped: $flipped)
```
- 6 tiers (`MembershipTier`), tilt +-14 degrees (pointerX * 28), perspective 900, lift 10; glare (soft-light), edge glint, holographic foil (conic hue shift, 115 degree comb mask), per-tier material (brushed lines, meridians, sunburst, guilloche), 6 s idle shimmer, 700 ms bouncy flip, locked state (frost, ring, "N km to unlock").
- `live: true` tracks the pointer, click / Return / Space flips. `pose:` (-0.5...0.5) renders a fixed tilt. Metal is not used: layers are Canvas gradients. Reduce Motion: no tilt, no shimmer, static glare.
- The canvas' jetstream flow lines and obsidian constellation reference an undefined gradient id and render nothing in the canvas, so they are not drawn.

## StampView (Stamp.dc.html)

```swift
StampView(shape: .round /* .oval .octagon .rosette */, country:code:date:kind:cc:, ink: PaperStampInk.blue, rotation: -6, size: 150, locked: false, seed: 3, animation: .landing /* or .passport, nil */, onThump: { })
```
Seeded wear mask (the canvas' displacement warp is not reproduced). `animation: .landing` = 60 ms thump + 120 ms bleed; `.passport` = 460 ms. Ink colors from `PaperStampInk`. `onThump` fires at 60 ms (sound + heavy haptic).

## SplitFlapText (SplitFlap.dc.html)

```swift
SplitFlapText("MR 0142 · A12", length: nil, size: .m /* .xs .s .m .l */, tone: .amber /* .white */, dim: false, onFlap: { cell in })
```
Cells 20x30 / 22x32 / 30x44 / 42x62, flips 62 ms + 62 ms, 40 ms stagger, up to 5 flips per cell, hinge. `onFlap` fires for even cells, rate-limited to 25 per second. Reduce Motion: text changes immediately.

## Debug routes and verification

`paper-pass`, `paper-pass2..4`, `paper-card`, `paper-card2..3`, `paper-stamp`, `paper-flap` (`App/Meridian/Debug/PaperSheets*.swift`) draw contact sheets with the same layout as reference pages that import the canvas components (Ticket / Card / Stamp / SplitFlap) at fixed positions on the canvas background; see the scores in the task report.
