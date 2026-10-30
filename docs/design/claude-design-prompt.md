# MERIDIAN — Claude Design master prompt

> **How to use this file**
> 1. Upload the 15 images from `reference-images.zip` (unzip first; upload in two batches if the tool limits attachments). They are named `ref-01 … ref-15`; the prompt refers to them by those names.
> 2. Paste everything between `BEGIN PROMPT` and `END PROMPT`.
> 3. If the tool truncates a long prompt, paste PART 1 first (brief, tokens, foundations), then PART 2, 3, 4, 5, 6, 7 one at a time, each in a new message, with the line "Continue the same design system and file." in front.
> 4. "Meridian" is a placeholder product name. Replace it freely. The real name is undecided and must not be "FocusFlight".

---

## BEGIN PROMPT

# PART 1 — BRIEF, PRINCIPLES, FOUNDATIONS

## 1.1 What you are designing

Design the complete UI/UX system for **Meridian**, a **native macOS app (macOS 26 "Tahoe", Liquid Glass design language, built later in SwiftUI)** that turns every focus session into a **virtual flight**. The user picks a departure airport and a duration, the app suggests destinations whose real-world flight time matches that duration, the user checks in, a **boarding pass prints**, they **tear off the stub**, and the plane "flies" in real time on a 3D map while they work. When the timer ends the plane lands, the ticket is stamped, and the flight is saved into a **ticket wallet**, a **world map**, a **passport**, and a set of collectible **membership cards** that unlock with distance flown. Friends can **board the same plane** and see each other's seats and progress. The app also lives in the **menu bar**, in a **floating mini map window**, in **desktop widgets**, and on a **second monitor as a seat-back TV**.

The target users are students, developers, writers and people with ADHD who sit at a Mac for hours. The emotional promise: *calm, ritual, progress, a little wonder.* The product must feel like a **premium aviation object designed by Apple**, not like a gamified productivity toy.

Deliver a **complete, consistent, high-fidelity design system plus every screen, state and signature interaction listed below**, with interactive prototypes for the signature moments (ticket print, ticket tear with sound, membership card tilt). Design at **1x for a 1440×900 canvas**, show the app inside a realistic **macOS Tahoe window** (traffic lights, large concentric corner radius, floating glass sidebar). Dark mode is the primary mode; provide light mode for the main screens and all components.

## 1.2 Reference images (what to learn, what to improve, what NOT to copy)

The attached images come from an existing iOS competitor called FocusFlight. **Use them only to understand flows, information architecture and the quality bar.** Do **not** copy its visual identity: not its purple-navy + yellow-tag palette, not its card names or artwork (Concorde, Voyager, Spirit), not its illustrations, wordings or logo. Meridian must look clearly different and more refined. Where I say "improve", the competitor's users complained about it in reviews.

| Image | What it shows | Learn | Improve / change |
|---|---|---|---|
| ref-01, ref-09 | Home: dark map, origin dot with a translucent **range circle**, small rounded **airport tags** (plane glyph + IATA code), a **horizontal duration ruler** (30m–50m) with a pointer, a **dock of destination cards** (selected one is white, others dark; each shows code, city, duration), a pill CTA "Book My Flight", round glass buttons top-right (warning, shuffle/random, search) | The "pick duration, destinations appear inside the ring" mechanic is brilliant; keep the idea | Make the origin **editable and prominent** (users hated that it could not be changed). Add a Quick Start path. Make the ruler feel like a physical dial with detents. Design for a large Mac canvas, not a phone. |
| ref-02, ref-11 | Colourful **scenario chips** (Writing, Brainstorm, Planning, Meditation, Review, Exam, Read, Coding, Yoga…); onboarding version has chips that **float and collide with physics** | Playful, tactile selection | Our chips must feel premium (soft glass pills, restrained color), not toy-like. |
| ref-03 | **Boarding pass** (white, dot-matrix world map watermark, huge IATA codes LHR → CDG, seat, boarding time, distance, long barcode) and a smaller "LANDED" ticket, plus a serif **Notes** card | Boarding pass as the hero artifact; notes attached to a flight | Make the ticket a **physical, interactive object** (print, perforation, tear, stamp). Colour-code tickets. |
| ref-04, ref-10 | In-flight **satellite map** top-down, vertical route line, plane, side control stacks (pause, sound, lock, route, compass, map style), bottom "Time remaining / Distance remaining" | Calm, minimal HUD | Add camera zoom control while following the plane, day/night shading, a mini mode, and a proper phase timeline. |
| ref-05, ref-13 | **Window view**: an oval aircraft window frame with a real aerial view (Paris) | Great emotional anchor | Make it **alive**: day/night by real sun position, weather, clouds, wing, a pull-down **window shade**, take-off and landing views. Show a free preview so users can feel it before paying. |
| ref-06 | 3D globe with white **route arcs** | Elegant, minimal | Make arcs **colored by scenario** and animated; add time filters and visited-country shading. |
| ref-07 | **Membership cards**: brushed gold sunburst card, blue and black cards, km progress bar to next card, serif "Congratulations!" copy | Collectibles that reward distance; editorial serif tone | Make cards **3D, shiny and tilt with the mouse** (see §2.4). New original tier names and artwork. |
| ref-08 | Widgets ("Longest route", "Around Earth 0.3x" with serif numerals) and a **Live Activity** (LHR ▮▮▮▮ RTM, pause, mute, ON TIME, time remaining) | Data as elegant typography | Translate to macOS widgets, menu bar item and mini window. |
| ref-12 | Onboarding **map style picker** (Monochrome, Terra, Standard, Satellite, Labels toggle) | Simple 2×2 tile picker | Show live previews, available in Settings too. |
| ref-13 | **Paywall** with a hero (window), plan cards (Annual −60%, 7-day trial), rainbow-gradient CTA | Hero feature preview | Ours must be **honest**: total price, trial end date, "what stays free", cancel instructions, no countdown pressure. |
| ref-14 | Booking on satellite basemap | Real imagery under the range ring looks great | Keep as an option. |
| ref-15 | "Activate Airplane Mode and block distractions" with floating app icons | Blocking concept | On Mac blocking is **soft** (an overlay and a nudge), design it as such (§3 S51). |

## 1.3 Research-driven requirements (from 1,285 real user reviews; bake these in)

1. **Departure airport is always editable**, in the planner, in settings, and via "Continue from last landing".
2. **Friction kills.** Provide **Quick Start (⌘⏎)** that skips the ritual with last-used route and duration. The ritual (seat, check-in, print, tear) is optional and skippable forever.
3. **Mac needs a floating mini map** that stays on top and can be small ("like the in-flight map on a seat-back TV").
4. **The window view must feel real and change**: time of day, weather, altitude, take-off and landing.
5. **Cabin atmosphere**: announcements, seatbelt chime, a **"prepare for landing" heads-up 5 minutes before the end** (users were startled by an abrupt landing ding).
6. **Wallet must be colorful**: past tickets and visited destinations should be **color-coded** and filterable; the world map should show where you have been in color.
7. **Together**: friends **board the same plane**, pick **adjacent seats**, see each other on a passenger strip and on the map; there are also **public scheduled flights** for body-doubling with strangers.
8. **Short and long sessions**: 10 minutes to 6 hours, plus an open-ended "free flight". Break = **meal service** (optional Pomodoro).
9. **Trust**: never hide previously-free things behind a paywall; show prices and dates clearly; one purchase unlocks all Apple devices and Family Sharing.
10. **Mac-native**: menu bar, global shortcuts, keyboard-first, trackpad haptics, second display, no screensaver interruption.
11. **Reliability cues in the UI**: a flight survives sleep, quit and crash; show "Flight resumed" state, never silently reset.
12. **Neutral maps**: labels follow the user's locale; disputed names show both ("East Sea / Sea of Japan"); design a small "map labels" setting.

## 1.4 Art direction

**"Premium aviation editorial meets Liquid Glass."** Think: a first-class cabin at night, a Swiss airport signage system, a collectible travel document, rendered with Apple-level restraint.

- **Dark, calm, spacious.** Deep ink backgrounds, luminous routes, generous negative space. Light mode is "Daybreak": warm paper white and soft glass.
- **Two materials only:** (1) **Liquid Glass** for controls and panels floating over the map; (2) **warm thermal paper** for tickets and cards-as-documents. Everything else is the map and the dark ground.
- **One signature accent** (Jetstream Blue to Aurora Mint gradient) used sparingly for the plane, active route and primary actions; **Runway Amber** for airport tags and time-critical info.
- **Editorial serif** (New York) for emotional copy and card names; **SF Pro** for UI; **SF Pro Condensed Bold** for IATA codes; **SF Mono** for flight data.
- **Motion is physical and unhurried**: springs, inertia, slight overshoot, paper that behaves like paper.
- **No clip-art airplanes, no stock photos, no emoji, no neon glow stacks, no generic purple-blue gradients, no Material/Windows patterns, no hamburger menus.** The plane is a refined, simplified top-down silhouette we draw ourselves. Maps are stylized (dot-matrix and dark vector) or real satellite imagery placeholder; never a screenshot of someone else's map.
- Everything must be **implementable natively** later (SwiftUI, Metal shaders, `glassEffect`, `KeyframeAnimator`, `matchedGeometryEffect`, `rotation3DEffect`, `sensoryFeedback`, `NSHapticFeedbackManager`, AVAudioEngine). Do not rely on web-only tricks.

## 1.5 Design tokens (define these first, as variables, and use only them)

**Color — Dark "Night Cabin" (primary)**

| Token | Hex / value | Use |
|---|---|---|
| `bg-0` | `#06080D` | window base, deepest |
| `bg-1` | `#0B1020` | main canvas |
| `bg-2` | `#121A2E` | raised surfaces |
| `glass-tint` | `rgba(18,26,46,0.55)` | Liquid Glass tint |
| `stroke-hair` | `rgba(255,255,255,0.08)` | 1px hairlines |
| `stroke-glow` | `rgba(255,255,255,0.22)` | top inner highlight on glass |
| `text-1` | `#F3F5FA` | primary text |
| `text-2` | `#A9B2C7` | secondary |
| `text-3` | `#6B7592` | tertiary / disabled |
| `accent-1` | `#6AB7FF` | Jetstream Blue |
| `accent-2` | `#8BF3D8` | Aurora Mint |
| `accent-grad` | `linear-gradient(135deg,#6AB7FF,#8BF3D8)` | plane trail, primary CTA |
| `amber` | `#FFB547` | airport tags, ETA warnings |
| `paper` | `#F5F0E6` | ticket paper |
| `ink` | `#14110F` | thermal ink on tickets |
| `ok` / `warn` / `danger` | `#5BE3A0` / `#FFB547` / `#FF6B6B` | status |

**Color — Light "Daybreak":** `bg-0 #EDE9E1`, `bg-1 #F4F1EB`, `bg-2 #FFFFFF`, text `#14161C / #4A5163 / #8A91A3`, accent `#1E6BFF`→`#18C7A0`, glass tint `rgba(255,255,255,0.62)`. Tickets and cards look identical in both modes.

**Scenario (category) colors** (equal perceived lightness, use for tickets, route arcs, chips, charts): Study `#7AA2FF`, Work `#FFB86B`, Read `#7ADDB2`, Create `#FF8FB1`, Code `#B49CFF`, Meditate `#8EE3E8`, Fitness `#FF9B7A`, Other `#C7CCDA`.

**Cabin class by duration** (shown as a foil edge on tickets): Economy < 45 min (brushed steel), Premium 45–90 min (sky glass), Business 90 min–3 h (champagne gold), First 3–5 h (white-gold foil), Long-haul 5 h+ (holographic).

**Sky gradients for the window view** (by sun elevation): Night `#04060F→#0B1430`, Blue hour `#101B3D→#3B4C8F`, Sunrise/sunset `#2B2A5C→#FF8A5B→#FFD9A0`, Day `#4C97E8→#BFE0FF`, Overcast `#7C8798→#C9D0DA`.

**Typography:** UI = SF Pro. Scale (size/line): Display 56/60 (−1.2% tracking), Title 1 34/40, Title 2 24/30, Headline 17/22 semibold, Body 15/22, Callout 13/18, Caption 11/14 with +2% tracking and uppercase for labels. Numbers use **tabular figures**. IATA codes: **SF Pro Condensed Bold**. Flight data and countdowns: **SF Mono Medium**. Editorial: **New York** (serif) Medium/Semibold.

**Spacing (4pt grid):** 4, 8, 12, 16, 24, 32, 48, 64. **Radii (concentric rule: inner = outer − padding):** window 26, large panel 28, card 20, control 14, chip full, ticket 22 with 14 notch.

**Glass recipe (Liquid Glass look to reproduce in design):** blur 32–48 px, saturation 160%, tint `glass-tint`, 1 px `stroke-hair` outer border, 1 px `stroke-glow` inner top highlight, a faint 135° specular gradient across the surface, soft shadow `0 20 60 rgba(0,0,0,0.45)`. Controls over glass get slightly more opaque on hover (+6% white).

**Elevation:** e0 none, e1 `0 2 8 rgba(0,0,0,.25)`, e2 `0 8 24 rgba(0,0,0,.35)`, e3 `0 20 60 rgba(0,0,0,.45)`.

**Motion tokens:** durations 120 / 200 / 320 / 520 / 900–1400 ms. Easing `standard = cubic-bezier(0.2,0,0,1)`, `accelerate = cubic-bezier(0.3,0,0.8,0.15)`. Springs: Snappy (response 0.32, damping 0.82), Smooth (0.5, 0.86), Bouncy (0.55, 0.68), Heavy (0.7, 0.9). **Reduced Motion:** replace all movement with 200 ms cross-fades.

## 1.6 Window and layout system

- **Default window 1280×800**, minimum 960×640, fullscreen supported (also show 1728×1117 for the cruise view). Hidden title bar, traffic lights over content, toolbar items are floating glass buttons.
- **Floating glass sidebar**, 220 pt wide, collapsible to a 64 pt icon rail. Sections: **Fly** (Plan), **Wallet** (Tickets, Cards, Passport), **Map**, **Stats**, **Together**, then a footer with profile, miles ring and Settings. The active item has a soft accent-glow capsule. A small live "In flight" capsule appears at the sidebar top with remaining time while a flight is active, from any screen.
- **Content area** uses an 8-column grid with 24 pt gutters; map screens are full-bleed under the glass chrome.
- **Keyboard-first**: ⌘⏎ Quick Start, ⌘K command palette, ⌘1–5 sections, ⌘, settings, ⌥⌘M toggle mini map, Space pause/hold, Esc close sheets. Show shortcut hints in tooltips.

---

# PART 2 — SIGNATURE COMPONENTS (design every one, with all states)

## 2.1 Boarding pass (the hero artifact)

**Size at 1x:** 360 × 600 pt, portrait. Corner radius 22. Two parts: **main body** (top 450 pt) and **stub** (bottom 150 pt), separated by a **perforation line** at y = 450 with **half-circle notches of radius 14 cut out of both left and right edges** and a row of tiny dots (2 pt dots, 6 pt gap) along the line. Tiny caps label on the stub top: "TEAR HERE" with a scissors SF Symbol.

**Material:** warm paper `#F5F0E6` with 3% grain noise, an extremely subtle top-to-bottom sheen (white at 6% to transparent), a 1 px inner highlight at the top edge, and a soft contact shadow `0 24 48 rgba(0,0,0,.45)`. Type is **thermal ink** `#14110F` at 92% opacity with a hint of ink bleed (0.3 px blur duplicate at 20%).

**Anatomy, top to bottom:**
1. **Colored band** (6 pt) in the scenario color along the very top.
2. **Header (48 pt):** fictional carrier wordmark left ("MERIDIAN AIR" in letter-spaced caps, 11 pt) and "BOARDING PASS" right in caption caps. No real airline logos.
3. **Route block (130 pt):** left **FROM** code (e.g. `LHR`, SF Pro Condensed Bold 64 pt) with city under it (13 pt); center a dashed flight path with a small plane glyph and **duration** ("42 min", SF Mono); right **TO** code (`CDG`) with city. A **dot-matrix world map watermark** (like ref-03) at 8% opacity sits behind the route with both airports marked.
4. **Data grid (2 columns × 3 rows, 150 pt):** Date, Flight no. (e.g. `MR 0142`), Gate (`A12`), Seat (`1A`), Boarding time (`10:00`), Distance (`348 km`). Each cell has a caption label and a mono value.
5. **Scenario + topic row (56 pt):** a scenario chip (icon + "Coding") and an optional one-line topic.
6. **Passenger line (40 pt):** passenger name left, "Class: Economy" right with a foil-edge swatch.
7. **Perforation.**
8. **Stub (150 pt):** left a compact repeat (seat, gate, time); right a **wide PDF417-style barcode 300×56** with micro serial text. The barcode **draws left to right** during printing.

**Variants and states (design all):**
- **Printing** (partially revealed, see §2.2), **Printed**, **Torn** (stub removed, jagged edge, see §2.3), **Boarding** (a pulsing amber "BOARDING" status pill replaces the date), **In flight** (a glowing accent progress line fills along the bottom torn edge as the flight advances), **Landed** (green ink-stamp "LANDED" rotated −6° with slight bleed), **Diverted / landed early** (amber stamp "DIVERTED" with the flown fraction), **Group** (shows up to 6 tiny passenger avatars on the passenger line), **Locked/empty placeholder** for the wallet.
- **Wallet tile** version: the main body only at 0.55 scale, with the **torn bottom edge visible and unique per ticket** (a seeded jagged line, amplitude 1.5–2.5 pt), so every ticket in the collection has a different edge.
- **Color coding in the wallet:** user can color tickets by **Scenario** (band + code underline + stamp tint), **Class** (foil edge), **Continent** or **Month**. Provide all four views.
- **Hover (wallet):** ticket lifts 8 pt, tilts up to 6° toward the pointer, and its shadow lengthens. **Click:** it expands to full size and can **flip** to a back side with notes, route map and stats.

## 2.2 Ticket printing animation (design as a keyframed prototype)

Stage: center of the window on a dim, blurred map. A **thermal printer slot** (glass pill 420×14 pt with an amber status LED) hangs at the top of the stage.

Timeline (total ≈ 2.2 s):
- **0–200 ms:** the slot's LED blinks twice; the slot glows softly (amber) and a small contact shadow appears beneath it.
- **200–1800 ms:** the ticket **feeds out downward** from the slot in **stepwise motion**: about 14 steps, each step eases out over 100 ms then pauses 30–40 ms (mechanical stutter). A **print head line** (2 pt bright white line with a soft glow) sweeps downward just behind the paper edge; text and shapes **darken from pale gray to ink black** in a 250 ms heat-fade right after the head passes. The perforation and barcode are printed last (barcode draws line by line).
- **1800–2100 ms:** the ticket **overshoots by 6 pt and settles** with a Smooth spring and a 1.5° random rotation; the contact shadow grows as the ticket clears the slot.
- **2100 ms+:** a **"Tear here →" hint** appears along the perforation with a tiny animated chevron; the slot dims.
- **Sound** (see §5.2): stepper-motor printing chirps synchronized to the steps, a soft paper slide, and a tiny "tick" when it finishes.
- **Haptic:** a trackpad tick per step (14 ticks) and a heavier tick on settle.
- **Skippable:** pressing Space or Return during printing fast-forwards to the end.

## 2.3 Tear-off stub interaction (the star moment; prototype it)

The user **tears off the bottom stub by dragging it**. Behavior:

- **Affordance:** hovering the stub shows an open-hand cursor, the perforation dots brighten, and the stub lifts 2 pt.
- **Drag mechanics:** the user grabs the stub near either bottom corner and **pulls sideways and slightly downward**. **Tear progress** = drag distance projected along the perforation / ticket width. The torn portion is rendered with a **jagged clip edge** (seeded noise, 1.5–2.5 pt amplitude) that **follows the tear front** exactly. The stub **rotates around the tear front** as a pivot (up to 25°) and the stub's paper bends slightly (a 4 pt curl near the front).
- **Paper fibers and particles:** 3–6 tiny paper bits (1–3 pt, cream colored) pop off the tear front and fall with gravity; the torn edge shows a thin lighter fibrous rim (a 1 pt lighter jagged line).
- **Resistance:** easeInCubic resistance for the first 10%, then a steady pull; the ticket body shifts 1–2 pt toward the drag direction (tension), then springs back when the tear completes.
- **Sound (continuous, driven by drag):** a **paper-rip** whose **volume and pitch follow drag velocity**; it stops instantly when the user stops dragging. See §5.2 for a Web Audio recipe.
- **Haptics:** a light trackpad tick every 6% of progress; a stronger "release" tick at completion.
- **Threshold:** at **≥ 72% progress** the tear **auto-completes** (accelerating rip sound) and the stub **flies off** with the drag's velocity and spin, **shrinks and flies into the Wallet icon in the sidebar** (matched geometry), where a soft thud plays and the icon shows a "+1" badge. Under 72% on release, the stub **stays attached, the partial tear stays visible**, and the user can continue.
- **After the tear:** the main ticket's bottom edge is now jagged; the ticket **lifts and slides up** and morphs into the **Boarding / gate screen** (S14), then the flight starts.
- **Accessibility alternatives:** a visible **"Tear" button** and the keys Space/Return trigger the same animation automatically; Reduce Motion plays a quick fade and the rip sound only; VoiceOver announces "Boarding pass printed. Activate to tear off the stub."
- Design the **same interaction for the group ticket** (each friend's stub tears off in sequence when the group boards).

## 2.4 Membership card (shiny, tilts and bends with the mouse; prototype it)

**Size:** ID-1 ratio 1.586 → **340 × 214 pt** in lists, **480 × 303 pt** in the hero carousel. Corner radius 20. Provide **6 original tiers** with distance thresholds and distinct materials:

| Tier | Km to unlock | Material |
|---|---|---|
| **Departure** | 0 | frosted brushed steel, pale blue edge light |
| **Cruise** | 1,000 | sapphire gradient glass with fine meridian-line engraving |
| **Jetstream** | 5,000 | aurora holographic foil, color shifts with angle |
| **Meridian Gold** | 20,000 | **brushed-gold sunburst** (anisotropic radial lines), serif emboss |
| **Equator** | 40,075 ("once around the world") | white-gold with a thin world-circle guilloche |
| **Obsidian** | 100,000 | matte black, mirror-polished edge, subtle foil constellation |

Each card shows: tier name (New York serif, embossed), tiny tagline in serif italic, member number in SF Mono, "Member since …", a **chip** glyph, and the app mark.

**Interaction (design the prototype with these exact behaviors):**
- **Pointer-driven 3D tilt:** card rotates in 3D with perspective 900 pt. `rotateY = (pointerX − centerX)/width × 14°`, `rotateX = −(pointerY − centerY)/height × 14°`. Slight **bend**: the card's surface is subdivided (or approximated with a gradient mask) so the far edge appears to curve by 2–3 pt.
- **Specular glare:** a radial highlight (white 35% → 0, radius 60% of card width, blend soft-light/overlay) **follows the pointer**. A narrow **edge glint** brightens on the side facing the pointer.
- **Holographic foil:** a linear/conic gradient whose angle and hue shift ±60° with the tilt (saturation 60%), masked to the foil areas (logo, constellation, guilloche), clearly stronger on Jetstream and Obsidian.
- **Brushed-metal anisotropy** (gold/steel): radial sunburst lines whose brightness changes with the angle between pointer and card center.
- **Parallax layers:** background pattern at z=0, emblem at 12 pt, text at 24 pt, chip at 36 pt; each layer moves up to 6 pt opposite to the tilt.
- **Shadow:** `0 30 40 rgba(0,0,0,.45)` that **shifts opposite** to the tilt and softens as the card rises (hover lift 10 pt).
- **Return:** on pointer leave, spring back to flat with Smooth spring (≈ 600 ms) while the glare fades.
- **Idle shimmer:** when untouched, a soft sheen sweeps across every 6 s.
- **Click to flip:** rotate 180° around Y in ~700 ms (Bouncy spring). The **back** shows a magnetic-stripe band, total distance, flights, hours, "Next card: Meridian Gold — 16,922 km" with a progress bar in the tier's color, and a small "Share" action.
- **Locked cards:** frosted and desaturated with a lock glyph, "14,300 km to unlock" and a progress ring; they still tilt but with a dull specular.
- **Unlock / tier-up moment (S33):** a dark overlay, the new card **rises out of a slim sleeve** with a light burst, serif "Congratulations" types on, tiny paper-plane particles drift (subtle, 12 particles), a chime plays, and the sidebar's miles ring pulses.
- **Carousel:** a 3D coverflow (center card large, sides rotated −28°/28°, scaled 0.8, blurred 2 px).

## 2.5 Destination picker (the planning heart, based on ref-01/09 but better)

- **Map:** full-bleed dark map (Night Cabin) with the **origin dot** and a **translucent range ring** whose radius equals the selected duration. Airports inside the ring appear as **airport tags**: Runway-Amber rounded rectangles (radius 8) with a plane glyph and IATA code (SF Pro Condensed Bold 13), subtle inner glow; the selected tag grows 1.15× and is joined to the origin by a **luminous great-circle arc**.
- **Duration dial/ruler:** a **horizontal ruler** along the bottom with ticks every 5 min and labels every 30 min (10 min to 6 h + an "∞ Free flight" end stop). Dragging the ruler scrolls like a physical dial with **detent haptics** at 5-min steps and **the range ring resizing in real time**. Show the pointer flag with the exact time ("42 min") in SF Mono. A segmented quick-set row above: 15 · 25 · 50 · 90 · 2h.
- **Destination dock:** a horizontally scrollable row of destination cards. Each card: IATA tag, city, country flag (as a small flat circle, not an emoji), flight time ("41 min"), and a mini great-circle thumbnail. The **selected card is paper-white**, others are dark glass. Keyboard: ←/→ to cycle, ⏎ to confirm.
- **Origin chip** top-left: "From **LHR** · London ▾" — click opens a searchable popover (airport name, IATA, city, distance), with **"Use my location"**, **"Continue from last landing: CDG"**, and **favorites**. This chip is always visible.
- **Round glass buttons top-right:** Random destination (shuffle), Search, Map style, Info.
- **CTA:** a large glass pill **"Check in"** (accent gradient on hover) and a secondary **"Quick Start ⌘⏎"**.
- **Scenario & seat row** above the dock: the chosen scenario chip, a **Solo / Together** toggle, and a **Ritual / Quick** toggle.

## 2.6 Airport tag and scenario chip

- **Airport tag:** amber rounded rectangle, plane glyph + code; states: default, hover (lift + tooltip with airport name and distance), selected, visited (adds a small filled dot in the scenario color of your most frequent scenario there), disabled (outside ring).
- **Scenario chip:** glass pill with SF Symbol icon + label in the scenario color; states: default, hover, selected (filled with a 20% color tint and a 1 px color ring), editing (shows a small color picker and icon picker). Onboarding version uses a **physics playground** (chips fall, collide, settle; selected chips lift and glow).

## 2.7 Seat map (ritual step)

A calm top-down cabin: a fuselage cross-section in dark glass with **3-3 seating**, rows 1–12 visible, aisle highlighted, window seats marked with a tiny window glyph. Seat states: free, selected (accent ring + subtle lift), taken by friend (avatar bubble), unavailable. **Scenario is chosen by the "cabin zone"**: tapping a zone (Study, Work, Read, Create) selects the scenario and tints the zone. Window seat selection previews the **window view** (small oval). The selected seat number animates into the ticket's seat field via matched geometry.

## 2.8 Window view component (oval aircraft window)

An oval window (aspect 0.72, thick dark-gray frame with an inner bevel, a double-pane highlight, and a faint reflection streak) centered on a dark cabin wall. Inside: the **real-time sky** (token gradients by sun elevation), **clouds** in three parallax layers, a **wing tip** partially visible for window seats, and terrain/satellite imagery or stylized ground below. **A pull-down shade**: drag the shade handle down/up to close/open (physical spring), with a small light leak at the bottom edge when nearly closed. Variants: day, blue hour, sunset, night (city lights as warm dots), rain on glass (droplets running, blur), thunderstorm flashes (rare and subtle), take-off tilt, landing approach (runway lights). Show a **"Free preview" ribbon** state and a **locked state** for Pro scenes with a quiet unlock hint.

## 2.9 Flight HUD and phase timeline

- **Primary readout:** huge remaining time (SF Mono Medium 72 pt) with a thin progress arc or bar; "ON TIME +0 min" pill (green); ETA clock.
- **Phase timeline:** Boarding → Taxi → Take-off → Climb → Cruise → Descent → Landing as a horizontal glass track with a glowing current dot and phase labels; completed phases dimmed.
- **Secondary data (SF Mono, 13 pt):** distance remaining, ground speed, altitude, local time at destination, tailwind. Use plausible numbers.
- **Side control stacks** (round glass 40 pt buttons): left: Pause/Hold-to-land, Sound, Lock; right: Follow plane, Route, Map style, Window view.
- **Camera zoom slider** while following the plane.

## 2.10 Route line and plane marker

- A **great-circle arc** drawn with an **accent gradient trail** behind the plane and a thin dashed future path ahead. Trail is 3 pt, glow 8 px at 30%. Completed routes in the globe view are 1.5 pt arcs colored by scenario with 60% opacity, brighter on hover.
- **Plane marker:** a refined **top-down silhouette we draw ourselves** (not a clip-art plane), 28 pt, with a soft shadow on the map and navigation lights (red left, green right, white tail) that blink subtly. Provide **3 aircraft variants** (twin-jet, wide-body, turboprop) for future customization.

## 2.11 Map styles (design the four previews and all four versions of the in-flight screen)

**Monochrome** (ink and paper-white land), **Terra** (dark globe with subtle terrain relief and atmosphere rim), **Standard** (muted modern road/land map), **Satellite** (real imagery with a darkening gradient at screen edges so glass stays legible). Add a **Labels** toggle. Show the **dot-matrix** world as an additional stylized mode used on tickets and widgets.

## 2.12 Passport and stamps

A **passport page spread** (paper, two columns) with **country stamps**: each stamp is an original circular or rectangular ink stamp with country code, airport code and date, **rotated randomly ±12°**, slightly bled, in the scenario color (ink-blue, red, green variations). **Stamping animation:** a rubber stamp icon thumps down (60 ms), ink spreads with a 1.05→1.0 scale bleed, a low "thunk" plays. Locked countries appear as dotted outlines with the country name. A **filter**: by year, by scenario.

## 2.13 Sound mixer and announcements panel

A glass panel with **layered sliders**: Cabin hum, Rain, Ocean, Forest, Brown noise, Pink noise, Soft music, each with a tiny live waveform and a mute dot. A **master** slider and a **"Duck announcements"** toggle. Below: toggles for **Captain announcements**, **Cabin crew chimes**, **Seatbelt sign**, **Landing heads-up (5 min before)**, **ATC chatter**. Presets row ("Deep Work", "Night Flight", "Rainy Read") as chips.

## 2.14 Stats components

Day/Week/Month/Year segmented control; **bar chart** of focused hours (bars in scenario colors, stacked); **heat-map calendar** (GitHub-style, 7×N, accent intensity); **goal ring** (daily target, accent gradient arc, center shows hours); **streak flame replaced by a tail-wing chevron badge** (no emoji); **top scenarios** list with horizontal bars; **flights count, distance, countries, longest flight** tiles with serif numerals like ref-08. Hover shows a tooltip with exact data. Provide an **export** (CSV/PDF) button and a **"Your year in flight"** recap (S37).

## 2.15 Social components

- **Avatar** (circle 32 pt, initial or image, presence dot: focusing = accent, idle = gray, left = amber).
- **Passenger strip** (horizontal row of avatars with seat numbers and a tiny progress of "still on board").
- **Seat occupancy** in the seat map.
- **Invite card** (link, QR, "Copy link" button, "Boarding opens in 04:12" countdown).
- **Departures board** for public flights (split-flap, §3 S45).

## 2.16 System UI kit (all states: default, hover, pressed, focused, disabled)

Buttons (primary gradient, secondary glass, tertiary text, destructive, icon round), segmented control, toggle, slider, stepper, text field, search field, popover, context menu, sheet, alert, tooltip, toast, badge, progress bar, loading skeleton, empty state illustration style (line drawing, 1.5 pt, accent), keyboard focus ring (2 pt accent with 2 pt offset). **Split-flap** text component (letters flip with a 3D card flip and clack, 40 ms per character cascade).

---

# PART 3 — SCREENS (design every one; label with the ID)

## Onboarding

- **S01 Welcome:** slow-rotating 3D globe with a single route arc and a plane; large editorial headline ("Fly into focus." as placeholder); CTA "Let's get started"; a quiet skip link.
- **S02 Home airport:** auto-detected city card with a map pin ("We think you're in London. Change?"), searchable airport list, "You can change this anytime" reassurance.
- **S03 Choose your scenarios:** the physics chip playground (ref-11) in our premium style; chips collide softly, selected ones lift and glow; counter "3 selected".
- **S04 Map style:** 2×2 live-preview tiles (ref-12 idea) + Labels toggle.
- **S05 Permission warm-ups:** three steps, each with a friendly pre-prompt before the system dialog: Notifications (boarding call, landing soon), Focus filter (Do Not Disturb during flights), Accessibility for soft blocking (explain clearly what is and isn't read).
- **S06 Account:** optional Sign in with Apple for Together and iCloud sync, with a clear "Not now".
- **S07 Ready for take-off:** a short celebratory moment, an empty ticket outline fading in, CTA "Plan my first flight".

## Core flow

- **S10 Plan (Home):** the destination picker of §2.5 inside the app shell, full-bleed map, floating glass chrome. Include the **empty / first-run** state with a coach mark on the ruler.
- **S11 Search and random:** a command-palette-style overlay (⌘K) with airport search (code, city, country), "Surprise me" (Random Route) with a short slot-machine split-flap reveal of the destination.
- **S12 Seat and scenario:** the seat map (§2.7) with scenario zones, topic text field ("What are you working on?"), and a small "Together" invite row.
- **S13 Check-in and ticket printing:** the printing stage (§2.2) on a dim blurred map; a quiet progress hint.
- **S14 Tear and boarding gate:** the tear interaction (§2.3), then the **gate screen**: a split-flap departure board line for this flight ("MR 0142 · LHR → CDG · BOARDING"), the ticket pinned top-left, a 3-second boarding countdown, "Close your other windows? (soft blocking is on)" status chip.
- **S15 Take-off sequence:** cinematic ≈ 6 s: runway lights, speed lines, camera tilts up, the map rises beneath; optional cabin "boarding complete" chime; skip button; Reduced Motion version is a simple crossfade.
- **S16 Cruise, map view:** full-bleed map in the chosen style, glass HUD (§2.9), plane (§2.10), side control stacks, **camera zoom slider**, day/night terminator shading on the globe in Terra mode, "Hold to land early" control at the bottom-right.
- **S17 Cruise, window view:** §2.8 filling the window with the HUD compressed to a thin glass bar at the bottom; a seat-back "screen" toggle to flip to the map.
- **S18 Cruise, minimal dashboard:** a black screen with only the huge remaining time, a thin progress line and the destination; for fullscreen on a secondary display.
- **S19 Pause / land early / divert:** a glass sheet with three policies shown as cards: **Strict** (no pause), **Normal** (land early; partial flight saved), **Flexible** (pause up to 10 min). The destructive action is **"Hold to land early"**: press and hold 1.5 s while a ring fills around the button; a short, honest message that shows what will be saved ("You flew 31 of 42 minutes. 248 km will be counted.").
- **S20 Meal service (break):** an optional overlay at set intervals: a tray-table illustration (line art), "Meal service — 5 minute break", a countdown, "Skip break" and "Extend". The flight continues in the background.
- **S21 Descent and "Prepare for landing":** at T−5 min a soft toast slides in with a seatbelt-sign icon and a gentle chime: "Cabin crew, prepare for landing"; the HUD turns amber for the last minute; the window view shows approach lights.
- **S22 Landing and arrival:** touchdown animation, a green **LANDED** ink stamp thumps onto the ticket, summary tiles (time focused, distance, miles earned, streak), an optional **Notes** field ("What did you get done?") styled like the serif Notes card of ref-03, buttons "Add to wallet" and "Fly again from CDG" (continues from the landing airport), and a **Share card** (image) button.
- **S23 Wallet-in:** the landed ticket shrinks into the wallet, the miles ring animates, and if a threshold is crossed, S33 starts.

## Collection

- **S30 Wallet / Tickets:** a **grid of ticket tiles** (§2.1 wallet variant) with the **Color by** control (Scenario / Class / Continent / Month), filters (year, scenario, class), a search field and a **Stack view** (tickets stacked like a physical bundle, scrolling fans them out). Empty state with a ghost ticket.
- **S31 Ticket detail:** the ticket enlarged center, hover tilt, click flips to the back: notes (serif), route map, stats, and edit/delete/share. The **torn edge** is visible at the bottom.
- **S32 Membership cards:** the 3D coverflow of §2.4 with a **progress bar to the next card** (km, in tier color), "Joined … for 365 days" line, and the total km vs. Earth's circumference ("0.3× around the world").
- **S33 Unlock / tier-up:** the unboxing moment from §2.4 plus a "Congratulations" editorial paragraph in serif.
- **S34 Passport:** the stamp spread of §2.12, with a countries counter and filters.
- **S35 World map:** a full-bleed globe/flat map toggle; **visited airports and countries colored** by frequency (intensity) and optionally by scenario; all routes as a luminous network; a **time scrubber** at the bottom to replay your travels; a side list of "Top airports".
- **S36 Stats:** §2.14 components arranged in a calm bento layout.
- **S37 Year in flight (recap):** a vertical, shareable, editorial story: hours, distance, favorite scenario, longest flight, busiest day, a map of all routes, and the card tier reached. Includes **Share** (image).

## Together

- **S40 Friends:** list with presence, "Add friend" (username / invite link / QR), requests, privacy note ("Friends see your flight status, never your task or location").
- **S41 Create shared flight:** choose route and duration, set a **boarding time** ("Gate opens in 10 min"), generate an **invite card** (link, QR), set group size (max 8), public/private toggle.
- **S42 Lobby / boarding gate with friends:** the **shared seat map** with friend avatars placed on seats, adjacent-seat selection, live "Anna is at the gate", a countdown, and **each person's stub tears off** in sequence as they check in.
- **S43 In-flight shared view:** the cruise view with a **passenger strip** along the top, friend planes optionally visible as small markers when they are on different routes, a quiet "Anna landed" toast, no chat (status only).
- **S44 Group landing:** a **group ticket** showing everyone's initials, collective hours, a shared stamp, and a "Fly again together" button.
- **S45 Public scheduled flights:** a **split-flap departures board** ("TK 0900 · IST → NRT · 50 min · 128 aboard · BOARDING IN 06:12") with filters by duration and scenario, join button, and a calm note on community guidelines.

## Settings and Pro

- **S50 Settings:** a sidebar-in-window layout with General, Flight, Focus and blocking, Sounds and announcements, Maps and labels, Appearance (themes, app icon, accent), Notifications, Shortcuts, Account and Pro, Data and privacy. Include **map labels setting** ("Show both names for disputed places").
- **S51 Focus and blocking (soft):** list of apps/sites with a **grid of app icons (placeholders)**, three modes (Off, Nudge, Strict overlay); a preview of the **soft-block overlay** that appears when a blocked app comes to the front: a glass card "You're in flight to Paris · 18 min left — Return to focus" with a smaller "Take a break" and "Land early" action.
- **S52 Sounds and announcements:** §2.13.
- **S53 Meridian Pro (honest paywall):** a hero with the window view, a clear **"What stays free" list first**, then plan cards: **Lifetime (one purchase, all Apple devices, Family Sharing)**, **Annual**, **Monthly** (design all as prices-as-placeholders). Show the **trial timeline** ("Today: free access · Day 5: reminder · Day 7: charge of $X unless canceled"), a plain "Cancel anytime in System Settings" with a link, "Restore purchases", Terms and Privacy. **No countdown timers, no fake discounts, no dark patterns.**
- **S54 State sheet:** empty states (no flights yet, no friends, no cards), errors (no internet, iCloud off, map failed), loading skeletons, **"Flight resumed"** banner after quit or sleep.

---

# PART 4 — SYSTEM SURFACES

- **M01 Menu bar item and popover:** a monochrome plane glyph + remaining time ("42:18") that updates every second; states: idle, boarding (amber dot), in flight, last minute (accent pulse), landed (check). **Popover 340 pt wide:** mini map with plane, remaining time, phase, pause/land buttons, sound toggle, "Open Meridian".
- **M02 Mini floating map window:** always on top, resizable, **three sizes** (compact 360×200, medium 480×270, large 640×360), glass border, rounded 20, drag anywhere, snap to screen corners, adjustable opacity, **hover reveals controls** (pause, sound, size, close) while the default state is chrome-free. A "click-through" mode and a small time chip.
- **M03 Seat-back TV (second display):** fullscreen black screen with a cabin-style UI: a big map with a floating info bar, a **screen-bezel** reflection, and a toggle to the window view.
- **M04 Widgets (macOS desktop):** small 158×158 ("Next card" ring), medium 338×158 ("Longest route" with arc and serif numerals; "Around Earth 0.3×"), large 338×354 (weekly hours chart plus current streak). Provide dark and light, and a **live in-flight widget** variant.
- **M05 Notifications:** boarding call, "Prepare for landing", "Anna joined your flight", "Gate opens in 5 min", with Meridian styling and action buttons.
- **M06 App icon and Dock:** three original icon concepts (a meridian-line globe with a plane trail; a boarding-pass stub notch; an oval window glow), each in default, dark, tinted and clear Liquid Glass variants; Dock states: idle, in flight (progress ring around the icon), badge for friend invites.

---

# PART 5 — MOTION, SOUND, ACCESSIBILITY

## 5.1 Signature motion list (design a motion spec for each)

Printing (§2.2), tear (§2.3), card tilt and flip (§2.4), ruler dial and range ring, tag selection (spring pop and arc draw in 420 ms), seat select (matched geometry into the ticket), take-off (6 s), phase change (dot glides along the timeline, label cross-fades), landing stamp (60 ms thump + 120 ms bleed), wallet-in (shrink and fly), tier-up unbox, passport stamp, split-flap cascade, window shade pull, mini window snap, sheet present (scale 0.96→1 with blur-in 240 ms).

## 5.2 Sound design (show a "Sound" annotation on each relevant frame; if the tool can play audio, synthesize these with Web Audio)

- **Printer:** square-wave stepper chirp, ~60 Hz repetition per step, plus a thin band-passed noise tick (3–5 kHz, 20 ms) on each step; total length ≈ 1.6 s.
- **Paper rip (tear):** white noise → **bandpass 1.5–4 kHz (Q≈0.8)** → amplitude envelope driven by **drag velocity** (0–1), with a crackle layer (random 2–8 ms clicks, density ∝ velocity) and a 150 Hz low thump at completion. Gate to zero when velocity is 0.
- **Stamp thump:** 80 Hz sine drop (80→45 Hz over 120 ms) + 3 ms noise click + soft room tail.
- **Seatbelt chime:** two sine tones 880 Hz then 660 Hz, 180 ms each, soft attack, gentle reverb.
- **Boarding chime / landing chime:** three-note ascending/descending bell (C5, E5, G5 / reversed) with long decay.
- **Card tilt:** none; **flip:** a soft "whoosh" (filtered noise sweep 400→1200 Hz, 250 ms).
- **UI taps:** very quiet 12 ms clicks; all sounds respect a global "UI sounds" toggle.

## 5.3 Accessibility and platform quality

Contrast ≥ 4.5:1 for text, ≥ 3:1 for large text and icons (check amber on dark and paper text); full keyboard operation with visible focus rings; **VoiceOver labels** for every interactive element (document the label for the ticket, stub, ruler, cards); **Reduce Motion**, **Reduce Transparency** (glass becomes solid `bg-2`), **Increase Contrast** variants for the glass and tag components; Dynamic-Type-style scaling of the type scale to 130%; localisation-ready layouts (German and Turkish run ~30% longer; right-to-left support noted); no color-only meaning (always pair color with an icon or label).

---

# PART 6 — COPY DECK (use these exact strings; they set the tone: warm, concise, quietly witty)

- Headline: "Fly into focus." · Sub: "Pick a destination. Land your work."
- Quick Start button: "Quick start" (hint "⌘⏎")
- Ritual CTA: "Check in"
- Ticket hint: "Tear here →" · After tear: "Boarding complete. Have a calm flight."
- Gate: "Boarding" · "Doors close in 3…"
- Phase labels: "Boarding · Taxi · Take-off · Climb · Cruise · Descent · Landing"
- Landing heads-up: "Cabin crew, prepare for landing. 5 minutes to go."
- Land early: "Hold to land early" · Message: "You flew 31 of 42 minutes. 248 km will be counted."
- Landed: "Landed in Paris." · Notes prompt: "What did you get done?"
- Wallet empty: "No tickets yet. Your first flight will print here."
- Card unlock: "Congratulations. You've traveled 20,000 km — farther than most people travel in a lifetime." (placeholder)
- Together: "Boarding with friends" · "Anna is at the gate" · "Anna landed"
- Paywall: "What stays free" · "Pay once. Fly on every device." · "No surprises: you'll be charged $X on Nov 6 unless you cancel."
- Soft block overlay: "You're in flight to Paris — 18 min left." · "Return to focus" · "Take a break" · "Land early"
- Resumed: "Flight resumed. Your plane kept flying while you were away."
- Turkish samples (show at least one screen in Turkish to test length): "Odağa uç." · "Check-in yap" · "Bileti buradan yırt →" · "İniş için hazırlanın. 5 dakika kaldı."

---

# PART 7 — DELIVERABLES, PROTOTYPES, QUALITY BAR

## 7.1 Deliver these artboards, in this order

1. **Foundations:** color (dark + light), type scale, spacing, radii, glass recipe, elevation, motion curves, iconography rules.
2. **Component library:** everything in §2 with all states, side by side, in dark and light.
3. **Screens S01–S54** in dark; the main ones (S10, S16, S17, S30, S32, S36, S50, S53) also in light.
4. **System surfaces M01–M06.**
5. **Redlines** for the boarding pass, membership card, ticket printer, mini window and menu bar popover (dimensions, paddings, radii, type styles, color tokens).
6. **Motion and sound specs** as annotated frames or timelines.

## 7.2 Interactive prototypes (must actually work in the preview)

- **P1 Ticket ritual:** Plan → Check-in → printing animation → **drag-to-tear the stub with rip sound and haptic annotation** → boarding gate → take-off → cruise.
- **P2 Membership card:** pointer-driven tilt with glare and foil, idle shimmer, click-to-flip, locked card state, unlock moment.
- **P3 Planning:** dragging the ruler resizes the range ring and updates destination cards; changing the origin chip updates the map.
- **P4 In-flight:** cruise map ↔ window view toggle, pulling the window shade, "Prepare for landing" toast, "Hold to land early" ring, landing stamp.
- **P5 Together:** create shared flight, lobby with friend seats, each stub tearing in sequence.
- **P6 Mini map and menu bar:** resize the mini window, hover controls, menu bar countdown.

## 7.3 Quality bar and anti-patterns

- It must look like **one coherent premium product** and clearly different from the reference app.
- Use **only the defined tokens**; if you need a new value, add it to the token list first.
- **Pixel-aligned**, concentric radii, consistent 4pt spacing, optical alignment of icons and text.
- Every screen must show **real, plausible content** (airports, times, distances, names) rather than lorem ipsum, and **realistic Mac density** for a 1280×800 window.
- **Do not**: use emoji; use clip-art planes; copy the reference's colors, tags, card names or illustrations; use hamburger menus or mobile tab bars; add fake countdown/urgency in the paywall; use heavy neon glows or generic purple gradients; leave any interactive element without hover, pressed, focus and disabled states.
- Where a visual effect (glass, foil, shader) can't be reproduced exactly, **mock it as closely as possible and annotate** how it will be implemented natively in SwiftUI/Metal.
- At the end, add a short **"Designer's rationale and open questions"** page listing decisions you made and anything you'd like me to confirm.

## END PROMPT

---

## Notes for the product owner (not part of the prompt)

- **Reference images** are marketing screenshots of a competitor app, included only so the design tool can understand flows and quality. The prompt tells it explicitly not to copy artwork, names or palette, which also protects the app from App Store "copycat" review issues.
- **Videos:** I could not retrieve a public preview video (the App Store page exposes none to a script, the third-party showcase video is locked, no video tools are installed). The tear, print and tilt behaviors are therefore specified in words and numbers instead. If you screen-record the original on your iPhone/iPad (print animation, tear, card tilt, window view), send it and I will extract frames and refine §2.2–§2.4.
- **Open product decisions that may change screens:** product name, whether hard app-blocking ships (S51), whether Pro is lifetime-first, and the exact friend and public-flight rules (S40–S45).
