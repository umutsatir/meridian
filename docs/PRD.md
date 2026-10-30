# Meridian — Product Requirements Document

| | |
|---|---|
| **Product** | Meridian (working name; see Open Question Q1) |
| **Platform** | Native macOS app, SwiftUI + AppKit |
| **Status** | Draft v0.1 for kickoff, 30 Oct 2026 |
| **Owner** | Umut |
| **Design source of truth** | Claude Design canvas "Meridian — Design System", 179 artboards: <https://claude.ai/artifact/SLMJeFuvyjfXmkohJfjiAf> |
| **Research source** | `docs/research/FocusFlight Mac uygulaması araştırma raporu.md` (1,285 App Store reviews, competitors, Mac constraints) |

> **Türkçe özet.** Meridian, her odak seansını gerçek zamanlı bir "sanal uçuşa" çeviren, Mac'e özel yerel bir uygulama. Kullanıcı kalkış havalimanını ve süreyi seçer, süreye uyan varış noktalarından birini alır, check-in yapar, boarding pass basılır, alt kısmı yırtılır ve uçak 3B haritada süre boyunca uçar. İniş sonrası bilet cüzdana, dünya haritasına, pasaporta ve mesafeyle açılan üyelik kartlarına işlenir. Arkadaşlarla aynı uçağa binilebilir. Rakip FocusFlight'ın Mac'te yerel uygulaması yok; yorumlardaki en büyük şikayetler (kalkış noktası değişmiyor, pencere manzarası sabit, ücretli duvar, çökmeler, cevapsız destek) ürünün ilk günden çözmesi gereken şeyler. Tasarım hazır (179 artboard); bu PRD ne yapılacağını, nasıl doğrulanacağını ve hangi kararların hâlâ açık olduğunu tanımlar. Sonraki adım: M0 teknik denemesi (spike), sonra v1.0.

---

## 1. Summary

Meridian turns every focus session into a **virtual flight**. The user picks a departure airport and a duration. The app offers destinations whose realistic flight time matches that duration. The user checks in, a **boarding pass prints**, they **tear off the stub**, and a plane flies in real time over a 3D map while they work. When the timer ends the plane lands, the ticket is stamped, and the flight is kept in a **ticket wallet**, a **world map**, a **passport**, and a set of collectible **membership cards** that unlock with distance flown. Friends can **board the same plane**.

The product lives on the Mac: in a full window, a **floating mini map**, the **menu bar**, **desktop widgets**, and a **second monitor as a seat-back TV**.

**One-line pitch:** *Fly into focus. Pick a destination, land your work.*

## 2. Problem and opportunity

Students, developers, writers and people with ADHD spend hours at a Mac and lose focus. Generic timers are forgettable; the existing flight-themed focus apps are phone-first. Our research of the category leader (FocusFlight, 4.85★, ~9.8K ratings, iPhone/iPad/Mac-as-iPad-app) found:

- **Strong pull:** ritual (ticket printing, tearing, haptics), atmosphere (cabin sound), progress (routes, miles, cards). Users say "I focus to tear the ticket."
- **A Mac gap:** there is no native Mac app. A Mac user's review: "the app won't resize to be small… I'd like the map visible like an in-flight map on the TV."
- **Unmet needs, in descending evidence:**
  1. A living window view (≈60 reviews): time of day, weather, take-off and landing, real terrain.
  2. Flying with friends (≈40): same plane, adjacent seats, passenger list. The leader has teased "multiplayer" but has not shipped it.
  3. Choosing the departure airport (≈24 reviews, a repeated rage point).
  4. Cabin atmosphere: announcements, seatbelt chime, a warning before landing (≈dozens).
  5. A colorful collection: past tickets and visited places colored and filterable (≈27).
  6. Short and open-ended sessions, meal-service breaks (≈37); strong among ADHD users (≈23 mention ADHD).
- **Pain points we must not repeat:** paywall and trust problems (previously free features moved behind Pro in v2.0; surprise charges; refunds denied; support that never replies), crashes and data loss, battery and heat, unreliable blocking, disputed-name map backlash (Korean users: "East Sea / Dokdo"), too many taps to start.
- **Business reality:** the category is niche. A third-party report attributed less than $5,000 monthly revenue to the leader early in its life (the article's date is unverified). We plan a lean team and a generous free tier, not a large bet.

## 3. Target users

| Persona | Context | What they need from Meridian |
|---|---|---|
| **Elif, university student (primary)** | Exam prep, long library sessions on a MacBook | A ritual that makes starting easy, ambient sound, visible progress, a price she can accept, friends to study with |
| **Dev/knowledge worker** | Deep-work blocks at a desk, often two displays | A mini map that stays on top, menu bar countdown, keyboard-first control, no lag or heat, Focus-mode integration |
| **Person with ADHD** | Needs commitment and body-doubling | Short flights (10 min), open-ended flights, strict mode (no pause), quiet company on public flights, gentle landing warning |
| **Aviation fan** | Collector | Passport stamps, cards, cabin realism, window scenes |

## 4. Goals, non-goals, success metrics

### Goals (v1.0 and v1.5)
1. Ship the best-feeling native Mac focus app in the category, with the signature ritual (print, tear, board).
2. Make starting a session take **≤ 2 seconds** (Quick Start) or a satisfying ritual under 20 seconds.
3. Be calm on the machine: low CPU and energy impact, never heats the laptop.
4. Earn trust: fair free tier, transparent Pro, never lose a flight.
5. Add the social layer (friends and public flights) that the leader has not shipped.

### Non-goals (v1)
- iPhone, iPad, Apple Watch and Vision apps (architecture stays multiplatform-ready; see §17).
- Hard app blocking or anything that quits or hides other apps (see §9.11).
- Chat, comments, user-generated text in Together.
- Android and web clients.
- AI features, real flight data, real ATC audio, ads.

### Success metrics (initial hypotheses, to be calibrated after launch)

| Metric | Target |
|---|---|
| First flight started within the first session | ≥ 70% of new installs |
| Flights completed ÷ flights started | ≥ 75% |
| Day-7 retention | ≥ 25% |
| Weekly flights per active user | ≥ 5 |
| Mac App Store rating | ≥ 4.6 |
| Crash-free sessions | ≥ 99.5% |
| Energy impact (Activity Monitor) in cruise | "Low" for Terra/Mono/Standard maps; average CPU ≤ 10% of one core on an M1 at 30 fps follow-camera |
| Free → Pro conversion (30 days) | 3–5% |
| Refund rate | < 3% |

## 5. Product principles

1. **Ritual, then calm.** The ceremony is optional and skippable forever; the flight itself is quiet.
2. **Paper and glass.** Two materials: Liquid Glass for controls, warm thermal paper for tickets. Everything else is the map and the dark ground.
3. **Honest by default.** No countdown pressure, no fake discounts, no surprise charges, no shaming for empty data.
4. **Never lose a flight.** The plane keeps flying across sleep, quit and crash; the UI says so.
5. **Mac-native.** Keyboard-first, menu bar, trackpad haptics, multiple displays, Reduce Motion and Reduce Transparency respected.
6. **Original.** Name, art, sound and code are ours. Only the mechanic (a flight as a timer) is shared with competitors.

## 6. Scope and release plan

The Claude Design canvas already covers every screen below (S01–S54, M01–M06, motion and sound specs, redlines). Engineering ships it in slices.

| Release | Theme | Contents |
|---|---|---|
| **M0 Spike** (1–2 weeks) | Retire risk | MapKit 3D camera and energy profile; flight-engine package with tests; soft-blocking feasibility; SwiftUI feasibility of ticket print and tear; SwiftData + CloudKit model; Together backend decision |
| **v1.0 "Takeoff"** | Mac-first core | Onboarding; Plan; Ritual; Cruise (map, window with curated scenes, dashboard); mini map; menu bar; pause policies; meal breaks; landing; wallet, cards, passport, world map, stats, year recap; soft blocking; sound and announcements; settings; Pro (StoreKit 2); iCloud history sync; EN + TR; accessibility; widgets and notifications |
| **v1.5 "Together"** | Social | Friends; shared flights; lobby with stubs tearing in turn; passenger strip; group ticket; public scheduled flights |
| **v2.0 "Living cabin"** | Depth | Window view synchronized with the real route and terrain (MapKit); weather; take-off and landing sequences with terrain; more soundscapes; aircraft variants |
| **Later** | Expansion | iPhone/iPad companion and Live Activities; Watch; hard blocking (separate decision); more vehicles (train); more languages (DE, JA, KO, ZH) |

> *Change to the original research plan:* the Claude Design canvas treats the window view as a core, **free** feature (Pro adds the Satellite map and larger friend flights). v1.0 therefore ships the window with five curated scenes chosen by the sun's real elevation along the route; v2.0 replaces the curated scenes with live terrain.

## 7. Domain model and rules (shared by engineering and design)

### 7.1 Flights
- **Duration range:** 10 minutes to 6 hours, plus **Free flight** (open-ended, "∞" end stop).
- **Flight time from distance:** `minutes(km) = round(15 + km / 12.9)`; inverse `km(minutes) = max(0, (minutes − 15) × 12.9)`. (LHR→CDG = 348 km = 42 min.)
- **Short-flight rule (gap in the design, see Q10):** the formula gives 0 km for ≤ 15 minutes, so flights of 10–15 min would have no destinations. Recommended fix: overhead scales for short flights, `overhead(d) = min(15, d / 2)`, giving 10 min ≈ 64 km, 20 min ≈ 129 km, 30 min ≈ 194 km, continuous with the formula above.
- **Distance:** great-circle (haversine) between airports; the drawn route adds a mild lateral curve (cosmetic).
- **Cabin class by duration:** Economy < 45 min, Premium 45–90, Business 90–180, First 180–300, Long-haul ≥ 300. Shown as a foil edge on the ticket.
- **Scenario (focus type):** eight defaults, each with an icon and a color: Study, Work, Read, Create, Code, Meditate, Fitness, Other. Users can add custom scenarios.
- **Flight number and gate:** generated per flight (`MR` + 4 digits, gate letter + number); deterministic from a seed so the same flight always renders the same ticket.
- **Flight phases:** Boarding, Taxi, Take-off, Climb, Cruise, Descent, Landing, with proportional timings (take-off and landing sequences are cosmetic and never extend the timer).
- **State machine:** `planned → boarding → inFlight ⇄ onBreak → landed | landedEarly(diverted)`; `inFlight` can be `resumed` after sleep/quit.

### 7.2 Progress is computed, never ticked
Flight state stores `startedAt`, `durationSec`, `pausedTotalSec`, `status`. Elapsed time is `now − startedAt − pausedTotalSec`. Nothing depends on a running timer, so quit, sleep and crash do not change the result. On launch and on wake (`NSWorkspace.didWakeNotification`) the app recomputes elapsed time and shows the **Flight resumed** banner (S54).

### 7.3 Pause policies
| Policy | Behavior | Early landing |
|---|---|---|
| **Strict** | No pause. "The plane keeps its schedule." | Not available |
| **Normal** (default) | No pause; **hold 1.2 s** to land early; partial flight is saved | Counted proportionally |
| **Flexible** | Pause up to 10 minutes total | As Normal |

Land early shows what will be saved: "You flew 31 of 42 minutes. 248 km will be counted." The flight is marked **Diverted** with an amber stamp.

### 7.4 Breaks (meal service)
A break **holds the clock** and slides the ETA by the break length; **break minutes are never counted as focus or distance** (S20–S20D). Break length: timer, chosen length, or "until I'm back". The flight continues in the background after the break.

### 7.5 Distance, cards and streaks
- Only focused minutes become kilometres: `km = distance × focusedFraction`.
- **Membership cards (6 tiers, fictional):** Departure (0 km), Cruise (1,000), Jetstream (5,000), Meridian Gold (20,000), Equator (40,075, "once around the world"), Obsidian (100,000). Cards unlock once, never relock.
- **Streak:** consecutive days with ≥ 1 completed flight; a daily goal ring (hours) is configurable.
- **Passport:** one stamp per country on first landing; additional stamps for airports and milestones; stamp shapes are round, oval, octagonal and rosette, ink colors from the scenario of the flight.

### 7.6 Airport data
OurAirports (public domain), filtered to airports with scheduled service and IATA codes. We do **not** use OpenFlights route data (ODbL obligations). Airport names and country names are localized.

## 8. Information architecture

**Sidebar** (220 pt, collapses to a 64 pt rail): Fly (Plan), Wallet (Tickets, Cards, Passport), Map, Stats, Together; footer with profile, miles ring and Settings. An **In flight capsule** with the remaining time appears at the top of the sidebar from any screen.

**Window:** default 1280×800, minimum 960×640, fullscreen supported (1728×1117 reference for cruise). Hidden title bar, floating glass chrome, 8-column grid with 24 pt gutters.

**Global shortcuts:** ⌘⏎ Quick Start, ⌘K command palette and airport search, ⌘1–5 sections, ⌘, Settings, ⌥⌘M toggle mini map, Space pause/hold, Esc close sheets. Every action has a rebindable shortcut.

## 9. Functional requirements

Priority: **P0** = v1.0 required, **P1** = v1.5, **P2** = later. Design references point to the canvas artboard IDs. Every requirement is accepted only when its listed criteria pass.

### 9.1 Onboarding (S01–S07)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| ONB-1 | Welcome with a slow 3D globe, "Free to start · No account needed", skip link | P0 | First-run only; skippable at every step; EN and TR copy |
| ONB-2 | Home airport: auto-detect (coarse location, optional) or search | P0 | Works with location denied; always editable later (Settings > Flight, and the origin chip) |
| ONB-3 | Scenarios: physics chip playground, ≥ 1 selected, custom allowed | P0 | Chips collide and settle; selection persists; reduce-motion variant is a static grid |
| ONB-4 | Map style picker (Monochrome, Terra, Standard, Satellite*) with Labels toggle | P0 | Live previews; *Satellite locked to Pro with a quiet hint |
| ONB-5 | Permission warm-ups: Notifications, Focus filter, Accessibility (optional, see Q12) | P0 | Each step explains purpose before the system prompt; "Not now" never blocks |
| ONB-6 | Optional account (Sign in with Apple) for Together and iCloud | P0 | App fully usable without it |
| ONB-7 | "Ready for take-off" and CTA to plan the first flight | P0 | Leads directly into S10 with the first-run coach mark |

### 9.2 Plan (S10, S10B, S10F, S10L, S11, S11B)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| PLAN-1 | **Origin chip always visible and editable**; "Use my location", "Continue from last landing", favorites, search | P0 | Changing origin redraws ring and destinations in < 300 ms; persists as default |
| PLAN-2 | Duration ruler 10 min–6 h + Free flight; 5-minute detents; quick-set chips 15·25·50·90·2h | P0 | Dragging resizes the range ring in real time; trackpad detent haptics; keyboard ←/→ steps by 5 |
| PLAN-3 | Range ring and amber airport tags for destinations inside the ring | P0 | Tags are exactly the airports whose `minutes(km)` is within ±3 min of the selected duration (see §7.1); selected tag grows and an arc connects it to the origin |
| PLAN-4 | Destination dock of cards (code, city, flag, time, mini route) | P0 | Selected card is paper-white; ←/→ cycles; ⏎ confirms |
| PLAN-5 | Random destination ("Surprise me") with a split-flap reveal | P0 | Result is within the ring; reveal ≤ 1.5 s; reduce-motion shows result directly |
| PLAN-6 | ⌘K airport search by code, city, country | P0 | Results in < 100 ms offline |
| PLAN-7 | **Quick Start (⌘⏎)** uses last route, duration, scenario | P0 | Starts the flight in ≤ 2 s with ritual skipped when "Quick start checks in automatically" is on |
| PLAN-8 | Scenario chip, topic field, Solo/Together and Ritual/Quick toggles | P0 | Choices persist per user |
| PLAN-9 | First-run coach mark on the ruler | P0 | Shown once |

### 9.3 Ritual: check-in, print, tear, gate (S12, S12B, S13, S14A, S14B)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| RIT-1 | Seat and scenario sheet: cabin cross-section, scenario by zone, window seats preview the window | P0 | Selected seat flows into the ticket's seat field (matched geometry) |
| RIT-2 | **Ticket printing:** 14 steps of 84 ms ease-out plus a 30 ms hold; print-head line; ink darkens behind the head; barcode last; total ritual ≈ 2.1 s | P0 | Matches the T01 timeline; Space/Return jumps to the end; sound and haptics synchronized to steps |
| RIT-3 | **Tear the stub by dragging**: jagged edge follows the tear front; stub pivots up to 25°; resistance curve; velocity-driven rip sound; paper bits; haptic tick every 6% | P0 | Auto-completes at ≥ 72%; under 72% the stub stays attached with the partial tear; "Tear" button and Space/Return alternatives; VoiceOver labels |
| RIT-4 | Stub flies into the Wallet icon with a thump and a "+1" badge | P0 | Matched geometry; reduced motion = fade |
| RIT-5 | Boarding gate: split-flap departures line, pinned ticket, 3-second countdown, status chip "Soft blocking is on" | P0 | Doors close at 0; Enter/Space boards immediately |
| RIT-6 | Skip forever: Quick start and a setting to bypass the ritual | P0 | Setting persists |
| RIT-7 | Group version: each friend's stub tears in sequence at the lobby | P1 | See TOG-3 |

### 9.4 Take-off and cruise (S15A–C, S16, S16B–G, S16L, S16X, S17, S17E, S17L, S18)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| FLY-1 | Take-off sequence (full 6 s or short 2 s), skippable | P0 | Reduced Motion plays a simple cross-fade |
| FLY-2 | Cruise map in four styles (Terra, Monochrome, Standard, Satellite*), labels toggle | P0 | Follow camera with zoom slider; free-camera mode; style menu; day/night terminator in Terra |
| FLY-3 | HUD: remaining time in SF Mono, ON TIME pill, ETA, phase timeline, distance remaining, ground speed, altitude, local time at destination | P0 | Numbers consistent with the flight model; no network required |
| FLY-4 | Control stacks: pause/hold, sound, lock; follow, route, map style, window | P0 | Keyboard accessible; tooltips with shortcuts |
| FLY-5 | **Window view** with oval frame, pull-down shade, scenes by real sun elevation (day, blue hour, sunset, night, rain), wing for window seats | P0 (curated scenes) / P2 live terrain | Scene crossfades follow computed sun elevation along the route; shade drag with spring; free to use |
| FLY-6 | Dashboard view: huge remaining time, thin progress, destination; for second displays | P0 | Works fullscreen |
| FLY-7 | Plane marker and route trail (accent gradient, dashed future path), original silhouette | P0 | Three aircraft variants later (P2) |
| FLY-8 | Seat-back TV mode on a second display | P1 | Toggles between map and window |

### 9.5 Pause, land early, breaks (S19, S20–S20D)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| CTL-1 | Three policies Strict / Normal / Flexible (§7.3) | P0 | Policy chosen per flight, default in Settings |
| CTL-2 | **Hold to land early** (1.2 s) with a progress ring and an honest summary | P0 | Release cancels; saved fraction is exact |
| CTL-3 | Meal break overlay: tray-table line art, timer or chosen length or "until I'm back", Skip/Extend | P0 | Clock holds; ETA slides; break minutes never counted |

### 9.6 Landing and arrival (S21, S22, S23)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| LND-1 | **Prepare for landing** toast at T-5 min with seatbelt chime; HUD amber in the last minute | P0 | Setting to turn off; Time Sensitive notification when the app is in the background |
| LND-2 | Landing animation, green **LANDED** ink stamp (60 ms thump + 120 ms bleed) | P0 | Strict-mode flights stamp normally |
| LND-3 | Arrival summary: time focused, distance, miles earned, streak; optional Notes field; "Fly again from CDG" | P0 | Notes stay on device/iCloud; "Fly again" pre-fills origin |
| LND-4 | Share card (image) | P1 | No account needed |
| LND-5 | Wallet-in animation and miles ring pulse | P0 | Triggers card unlock when a threshold is crossed |

### 9.7 Collection: wallet, cards, passport, world map, stats (S30–S37)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| COL-1 | **Wallet grid of ticket tiles** with a unique seeded torn edge per ticket | P0 | Identical flight → identical edge |
| COL-2 | **Color by** Scenario / Class / Continent / Month; filters (year, scenario, class); search | P0 | All four views implemented; color never the only signal (icon + label) |
| COL-3 | Stack view with fan-out on scroll | P0 | |
| COL-4 | Ticket detail: hover tilt, flip to the back (notes, route map, stats), edit/delete/share | P0 | Notes editable; delete is confirmable |
| COL-5 | **Membership cards**: 3D coverflow, pointer-driven tilt (±14° at perspective 900), specular glare, holographic foil, brushed-metal anisotropy, parallax layers, idle shimmer every 6 s, flip to back, locked state | P0 | Matches R02; locked cards still tilt; reduce-motion disables tilt and uses a static sheen |
| COL-6 | Unlock moment (sleeve, light burst, serif "Congratulations") | P0 | Plays once per tier |
| COL-7 | Passport spread with stamps, drag page turn, filters | P0 | Stamp thump 60 ms; shapes per §7.5 |
| COL-8 | World map: globe/flat toggle; visited airports and countries colored by frequency or scenario; route network; time scrubber replay; top airports | P0 | Replay shows flights in order; masks are Natural Earth or MapKit |
| COL-9 | Stats: day/week/month/year bars, heat calendar, goal ring, streak badge, top scenarios, tiles (flights, distance, countries, longest flight), CSV/PDF export | P0 | Tooltips show exact values; export includes notes only when chosen |
| COL-10 | **Year in flight** recap, shareable | P1 | Image export |

### 9.8 Together (S40–S45) — v1.5
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| TOG-1 | Friends: add by username, invite link or QR; requests; presence | P1 | Friends see **status only, never task or location** |
| TOG-2 | Create a shared flight: route, duration, boarding time, group size (4 free, 12 with Pro), public/private, invite card (link, QR, 24-hour code) | P1 | Link works for 24 h; code revocable |
| TOG-3 | **Lobby with shared seat map:** friends on seats, adjacent seats, "Anna is at the gate", each stub tears in turn | P1 | Boards when all present or at the scheduled time |
| TOG-4 | In-flight passenger strip, optional friend markers, toasts ("Anna landed") | P1 | No chat anywhere |
| TOG-5 | Leaving a group flight does not break it; the leaver is "deboarded" | P1 | No punishment mechanics |
| TOG-6 | Group landing ticket with initials, shared stamp, "Fly again together" | P1 | |
| TOG-7 | **Public scheduled flights** board (split-flap), filters, quiet by design: no chat, no names | P1 | Anonymous counts only |
| TOG-8 | Safety: block, report, rate-limit invites, minimum age gate, moderation tooling | P1 | **Required before launch** (not yet designed, see Q4) |

### 9.9 Sound and announcements (S52, A01)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| SND-1 | Layered mixer: cabin hum, rain, ocean, forest, brown/pink noise, soft music; master; presets | P0 | Free: core set; Pro: 12 more soundscapes |
| SND-2 | Announcements: captain, cabin crew, seatbelt sign, landing heads-up, optional ATC; ducking | P0 | Each independently toggleable; all pre-rendered audio, not TTS |
| SND-3 | Sound recipes (printer, rip, stamp, chime, whoosh) rendered once into `AVAudioPCMBuffer`s | P0 | Rip volume and pitch follow drag velocity; stops at zero velocity |
| SND-4 | Respect "UI sounds" and system volume; never plays during Do Not Disturb unless the user allows | P0 | |

### 9.10 System surfaces (M01–M06)
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| SYS-1 | **Menu bar item:** plane glyph + remaining time every second; states idle, boarding, in flight, last minute, landed; 340 pt popover with mini map, pause/land, sound | P0 | Updates ≤ 1% CPU |
| SYS-2 | **Floating mini map** always on top, three sizes (360×200, 480×270, 640×360), drag, corner snap, opacity, hover-revealed controls, click-through mode | P0 | Persists size and position per display; hidden when no flight |
| SYS-3 | Widgets: small, medium, large; live in-flight widget | P1 | WidgetKit, dark/light |
| SYS-4 | Notifications: boarding call, prepare for landing (Time Sensitive), friend joined, gate opens | P0 | All mutable |
| SYS-5 | App icon (concept B "Stub") with default/dark/tinted/clear variants; Dock progress ring and badges | P0 | Legible at 16 pt |
| SYS-6 | Keep the display awake during flight (optional) and prevent screen saver | P0 | `IOPMAssertion` released at landing |

### 9.11 Focus and blocking (S51, S51B, S51C) — soft only in v1
| ID | Requirement | Pri | Acceptance criteria |
|---|---|---|---|
| BLK-1 | Three modes: Off, Nudge, Strict overlay | P0 | Strict overlay is **our own window**; nothing closes, hides or controls other apps |
| BLK-2 | App and website list with an app-icon grid; presets | P0 | Frontmost-app detection via `NSWorkspace` (see Q12) |
| BLK-3 | Overlay card "You're in flight to Paris — 18 min left" with Return to focus / Take a break / Land early | P0 | Appears when a listed app comes to the front |
| BLK-4 | macOS Focus filter: switch a chosen Focus on at take-off and off at landing | P0 | Per-flight opt-out |
| BLK-5 | Hard blocking (Network Extension, helper) | P2 | Separate decision; likely direct-distribution only |

### 9.12 Settings (S50–S50H)
Sections: General (menu bar, keep flying when the window closes, resume after sleep/quit, land-early hold), Flight (home airport, defaults, ritual speed, effects), Focus and blocking, Sounds and announcements, Maps and labels (style, **both names for disputed places**, dashed disputed borders, label density, trail color), Appearance (theme, app icon, accent), Notifications, Shortcuts (rebindable), Account and Pro (iCloud sync status, Pro, Family Sharing up to 5 people), Data and privacy (anonymous usage off by default, show flights to friends, export CSV/JSON, delete all data). **Acceptance:** every setting reversible and described in plain words; defaults match the "Used" column in Q1–Q12.

### 9.13 Pro (S53, S53B, S53L)
| Tier | Free | Pro |
|---|---|---|
| Flights | Unlimited, any length | Same; Pro never adds a timer to free features |
| Maps | Terra, Monochrome, Standard | **Satellite and flyover views** |
| Window view, cabin sound, announcements | Included | + **12 more cabin soundscapes** |
| Tickets, wallet, passport, stats | Included | Included |
| Friend flights | Up to **4** people | Up to **12** people |
| Menu bar, mini map, widgets | Included | Included |

- **Plans:** Lifetime (selected by default, one purchase, all Apple devices, Family Sharing), Annual (7-day trial), Monthly (7-day trial). Prices are placeholders (`$XX`, `$X`) until Q2 is decided. Suggested starting range from research: Lifetime $19.99–$29.99.
- **Honesty rules (acceptance criteria):** "What stays free" appears first; the trial timeline (Today, Day 5 reminder, Day 7 charge) and the exact charge date are shown; "Cancel anytime in System Settings"; Restore purchases; no countdown timers, no fake discounts, no dark patterns; features that were free are never moved behind Pro.
- **Technical:** StoreKit 2, universal purchase, Family Sharing enabled, server-side receipt validation not required in v1.

### 9.14 States, errors and resilience (S54)
Empty states ("No tickets yet. Your first flight will print here."), error states (no internet, iCloud off, map failed: "Your plane is still flying. We're showing the simple route until the map is back."), skeleton loading (1.4 s shimmer; Reduce Motion = static fill), and the three **Flight resumed** banners (after quit, after sleep, "Landed in Paris while you were away") that auto-dismiss after 8 s, never steal focus, and are read once by VoiceOver. *The third banner is new copy outside the deck and needs sign-off (Q7).*

## 10. Non-functional requirements

### 10.1 Performance and energy (initial budgets, validated in M0)
- Cruise screen: Energy Impact "Low", average CPU ≤ 10% of one core (M1, Terra, 30 fps follow camera), memory ≤ 400 MB.
- When the window is occluded or the screen is off: **no map rendering**, no animation timers; only the clock tick.
- Menu bar and mini map: ≤ 1% CPU when static.
- Launch to interactive: ≤ 1.5 s on M1.
- Plan screen range-ring drag: 60 fps with ≥ 500 airport tags culled by zoom.

### 10.2 Reliability
- A flight never resets (§7.2). One active flight per account; a second Mac shows "Flight in progress on MacBook Pro" and offers to take over.
- Crash-free sessions ≥ 99.5%; crash and hang reports via MetricKit/Xcode Organizer.
- Offline-first: everything except Together and iCloud works without a network; map tiles fall back to the simple route.

### 10.3 Accessibility
WCAG 2.2 AA contrast (text-3 was raised to `#96A0BA` dark / `#565E70` light to pass), visible focus rings, full keyboard operation, VoiceOver labels for every interactive element (ticket: "Boarding pass, London Heathrow to Paris Charles de Gaulle… Activate to tear off the stub."), Reduce Motion (printer removed, sound and haptics kept), Reduce Transparency (glass becomes solid `bg-2`), Increase Contrast variants, type scale up to 130%, no color-only meaning.

### 10.4 Localization
EN and TR at v1.0 (TR copy is a length test until a native review, see Q9); DE, JA, KO, ZH later. Layouts tolerate ~30% longer strings; RTL noted for later. All strings in String Catalogs; one product-name constant.

### 10.5 Privacy and security
- Data stays on device and in the user's iCloud unless Together is used. Together servers store account id, friendships, flight-room membership and aggregated public-flight counts; **never** task text, notes, topics or locations.
- Anonymous usage analytics **off by default**; no third-party ad or tracking SDKs.
- Sign in with Apple only; no passwords.
- Export (CSV/JSON) and delete-everything in Settings; delete removes server data too.
- Accessibility permission, if used, is requested only for frontmost-app awareness and explained before the system prompt.

### 10.6 Maps and labels
Disputed names show both ("East Sea / Sea of Japan", "Falkland Islands / Islas Malvinas") in the order the device region prefers; disputed borders are dashed; the map labels setting is visible and documented (Q5).

## 11. Technical approach

### 11.1 Stack
- **Swift 6, SwiftUI + AppKit bridges**, macOS 14+ target with `#available` styling for macOS 26 Liquid Glass (Q11).
- **MapKit** (SwiftUI `Map`, `MapCamera`, `.hybrid(elevation: .realistic)` for globe 3D; verify `.standard(elevation:)` fallback in globe mode in M0).
- **SwiftData + CloudKit** for flights, tickets, settings; **WidgetKit**, **App Intents**, **StoreKit 2**, **AVAudioEngine**, **Metal** (foil, stamp ink, sky), `KeyframeAnimator`, `matchedGeometryEffect`, `rotation3DEffect`, `sensoryFeedback` / `NSHapticFeedbackManager`.
- **Fonts:** the canvas uses Inter, Barlow Condensed, JetBrains Mono and Newsreader as stand-ins; native uses **SF Pro, SF Pro Condensed Bold, SF Mono, New York** (Q3 confirms).
- **Together backend (v1.5):** WebSocket rooms. Preferred: Cloudflare Workers + Durable Objects + Sign in with Apple (one Durable Object per flight room). Alternative: CloudKit sharing (no server, weak realtime presence). Decided after M0.

### 11.2 Native replacements for design stand-ins (from the designer's Z01)
| Canvas stand-in | Native implementation |
|---|---|
| Procedural satellite textures | MapKit satellite imagery, same framing and speed |
| Card bend and tear curl | `rotation3DEffect` plus a Metal distortion |
| Stamp ink (SVG displacement) | Metal mask with four stamp shapes and a seeded wear pattern |
| SVG globe and country masks | MapKit globe or Natural Earth outlines |
| Shortened seat map | Seat map follows aircraft type and friend count |
| Web Audio recipes | Rendered once to `AVAudioPCMBuffer`s |
| `backdrop-filter` glass | Liquid Glass materials |

### 11.3 Repository layout (proposed)
```
meridian/
  docs/            PRD.md, research/, design/ (link + export), decisions/ (ADRs)
  Packages/
    MeridianCore/  flight engine, geo math, airport DB, domain rules  (pure Swift, unit-tested; runs on Linux CI)
    MeridianUI/    design tokens, components (glass, ticket, card, split-flap), motion
  App/             macOS app target, features (Plan, Ritual, Cruise, Wallet, Together, Settings, Pro)
  Widgets/         WidgetKit extension
  server/          Together backend (v1.5)
```
`MeridianCore` has no Apple-framework dependency so cloud/Linux sessions can build and test it.

### 11.4 Data model (summary)
`Profile`, `Flight` (id, origin, destination, scenario, topic, notes, startedAt, durationSec, pausedTotalSec, status, focusedFraction, seed, groupId?), `Ticket` (derived from Flight), `Airport` (static, bundled), `Scenario` (default + custom), `CardUnlock` (tier, unlockedAt), `Stamp` (country/airport, flightId), `Friend`, `SharedFlight`. SwiftData + CloudKit rules apply: all attributes optional or defaulted, no unique constraints, relationships optional.

## 12. Release criteria (v1.0)
- All P0 requirements pass their acceptance criteria.
- Zero known data-loss bugs; flight survives quit, sleep, force-quit, crash (automated test).
- Energy and CPU budgets met on M1 and M4.
- VoiceOver, keyboard-only and Reduce Motion/Transparency walkthroughs pass.
- Pro purchase, restore, Family Sharing and refund flows verified in the StoreKit sandbox.
- EN and TR strings complete; TR reviewed by a native speaker.
- Map-label policy implemented and reviewed (Q5).
- Privacy labels, Terms, Privacy Policy and support email live; support SLA documented.
- App Store listing, screenshots and preview video prepared.

## 13. Risks and mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| MapKit 3D globe is slow or hot | Core experience | M0 profiling; budgets in §10.1; Terra/Mono as default; render pause when occluded |
| Soft blocking needs a permission we do not want to ask for | Onboarding drop-off | Use `NSWorkspace` frontmost-app notifications (no Accessibility permission); ask only if window titles are required (Q12) |
| Mac App Store rejection for blocking or overlay behavior | Launch delay | Keep our own window overlay only; no closing/hiding other apps; fallback to direct distribution |
| Together moderation and child safety | Legal and brand | Status-only design, no chat, block/report, age gate, moderation tooling before launch |
| Competitor ships multiplayer first | Differentiation | Mac-first, public flights, ship v1.5 quickly |
| Trademark and copycat | App Review, legal | Original name, art, sound, code; no real airline or alliance logos; check the name before icon work |
| Niche revenue | Sustainability | Lean team, generous free tier, one-time Lifetime |
| Audio licensing and production | Announcements, ambience | Original recordings or licensed packs; no real ATC audio |
| Map-name controversy | Reviews, uninstalls | Dual naming, dashed borders, setting; QA by region |

## 14. Analytics and feedback
Off by default and anonymous when on: flights started/completed/landed-early, ritual skipped, Quick Start used, map style, Pro paywall views and conversions, crash and hang metrics. In-app **Feedback** opens a prefilled email; support replies within 2 business days (a promise the leader failed to keep).

## 15. Open questions and recommended defaults
The canvas's own Z01 list is merged here with engineering questions. "Used" = what the design assumes.

| # | Question | Used in design / recommended default |
|---|---|---|
| Q1 | Product name? "Meridian" and "Meridian Air" on the pass are working names; the icon, pass header and Pro name depend on it | Meridian everywhere, in one string constant; run a trademark check before icon work |
| Q2 | Should Pro lead with Lifetime? | Lifetime selected; prices left as `$XX`; test $19.99–$29.99 |
| Q3 | System fonts or bundled fonts? | System faces (SF Pro, SF Condensed, SF Mono, New York) |
| Q4 | Rules for friends and public flights; reporting and moderation are not designed | Private by default; public flights anonymous; design block/report before v1.5 |
| Q5 | Disputed map labels policy | Both names, dashed borders; legal/QA review |
| Q6 | Which icon concept ships? | **B "Stub"** (survives at 16 pt) |
| Q7 | Who reviews new copy (banners, Settings, Paywall, notifications, Pro list)? | Drafts until owner sign-off; no exclamation marks, no countdown pressure |
| Q8 | Should break minutes count toward distance? | No. Only focused minutes become kilometres |
| Q9 | Is the Turkish copy final? | Only four deck strings are final; rest are length tests until native review |
| Q10 | Flights under 15–20 minutes have no destinations under the current formula | `overhead(d) = min(15, d/2)` (see §7.1) |
| Q11 | Minimum macOS version | macOS 14 (matches the leader's reach), Liquid Glass styling via `#available` on 26 |
| Q12 | Is the Accessibility permission needed? The design asks for it to see the frontmost app, but `NSWorkspace` activation notifications provide that without it | Avoid it in v1; request only if window titles are required |
| Q13 | Distribution: Mac App Store only, direct only, or both? | Mac App Store first (discoverability, StoreKit, Family Sharing); hard blocking decides later |
| Q14 | Together backend | Cloudflare Durable Objects + Sign in with Apple (spike) |
| Q15 | Pricing and trial lengths for Annual/Monthly | 7-day trial as in the design; confirm with Q2 |

## 16. Traceability: research insight → requirement
| Review insight | Requirement(s) |
|---|---|
| Can't change departure airport | PLAN-1, ONB-2, Settings > Flight |
| Window view static or paywalled | FLY-5, §9.13 (window free), v2.0 live terrain |
| Too many taps to start | PLAN-7, RIT-6 |
| Mac window can't be small; wants in-flight map | SYS-2, SYS-1, FLY-8 |
| Startled by landing chime | LND-1 |
| Wants announcements and cabin sounds | SND-2 |
| Wants colored tickets and visited places | COL-1…COL-3, COL-8 |
| Wants flying with friends | TOG-1…TOG-7 |
| Short sessions, ADHD, breaks | PLAN-2, CTL-1, CTL-3, TOG-7 |
| Paywall backlash, surprise charges, no support | §9.13 honesty rules, §14 |
| Crashes, resets, lost flights | §7.2, §10.2, S54 banners |
| Battery and heat | §10.1 budgets, render pause |
| Blocking unreliable | BLK-1…BLK-3 (soft, honest) |
| Map-name backlash | §10.6, Q5 |
| Family sharing / multi-device unlock | §9.13 (universal purchase, Family Sharing) |
| Wants Turkish and more languages | §10.4 |
| Screen saver interrupts on Mac | SYS-6 |

## 17. Future considerations
SwiftUI multiplatform packages (`MeridianCore`, `MeridianUI`) keep an iPhone/iPad companion cheap: Live Activities appear on the Mac menu bar via iPhone Mirroring on macOS 26. Active-flight sync across devices is deliberately out of v1; history sync via CloudKit is in. Hard blocking, more vehicles, aircraft variants and more languages follow.

## 18. Appendix A: design artboard index
Foundations F1–F3 (color, type/layout/icons, glass/motion). Components C01–C12 (boarding pass, print animation, tear-off, membership cards, destination picker, seat and window, flight HUD, map styles, passport and stamps, stats and sound, social, UI kit). Screens: S01–S07 onboarding; S10–S15 plan, ritual and take-off; S16–S23 cruise and landing; S30–S37 collection; S40–S45 Together; S50–S54 settings, focus, sounds, Pro, states. System surfaces M01–M06. Redlines R01–R05. Motion T01–T03. Sound A01. Prototypes P1–P6. Rationale Z01. Building blocks (importable components such as Ticket, Card, SplitFlap, WindowView, MapLayer, Planner, Flight, Together, Settings). Localisation tests L01, S01T.

## 19. Appendix B: design tokens (summary)
- **Dark "Night Cabin":** `bg-0 #06080D`, `bg-1 #0B1020`, `bg-2 #121A2E`, `text-1 #F3F5FA`, `text-2 #A9B2C7`, `text-3 #96A0BA`, `accent-1 #6AB7FF`, `accent-2 #8BF3D8`, `amber #FFB547`, `paper #F5F0E6`, `ink #14110F`, `ok #5BE3A0`, `warn #FFB547`, `danger #FF6B6B`.
- **Light "Daybreak":** `bg-0 #EDE9E1`, `bg-1 #F4F1EB`, `bg-2 #FFFFFF`, `text-1 #14161C`, `text-2 #424959`, `text-3 #565E70`, `accent-1 #1759E0`, `accent-2 #18C7A0`; status colors deepened (`ok #08613F`, `warn #8A4F05`, `danger #BC2D2D`).
- **Scenario colors:** Study `#7AA2FF`, Work `#FFB86B`, Read `#7ADDB2`, Create `#FF8FB1`, Code `#B49CFF`, Meditate `#8EE3E8`, Fitness `#FF9B7A`, Other `#C7CCDA`.
- **Spacing** 4/8/12/16/24/32/48/64 pt; **radii** window 26, panel 28, card 20, control 14, ticket 22 (notch 14); **type** Display 56/60, Title 1 34/40, Title 2 24/30, Headline 17/22, Body 15/22, Callout 13/18, Caption 11/14.
- **Motion:** durations 120/200/320/520/900–1400 ms; springs Snappy, Smooth, Bouncy, Heavy (SwiftUI equivalents listed in F3).
- **Authoritative source:** the canvas boards F1–F3 and `project/meridian.css`; new values must be added to the token list first.
