# Meridian

A native macOS focus timer where every session is a virtual flight. Pick a departure airport and a duration, check in, tear the stub off your boarding pass, and fly in real time while you work. Land to collect tickets, passport stamps and membership cards.

> **Archived (November 2026).** This project is finished and no longer maintained. It was never released on the App Store. The code is here, under the MIT licence, for anyone who wants to learn from it, take parts of it, or carry it on. Issues and pull requests will not be answered.

> **Türkçe özet.** Meridian, her odak seansını gerçek zamanlı bir sanal uçuşa çeviren yerel bir Mac uygulaması. Kalkış havalimanını ve süreyi seçersin, süreye uyan varış noktalarından biri önerilir, check-in yaparsın, boarding pass basılır, koçanı yırtarsın ve uçak sen çalışırken haritada gerçek pistten kalkıp uçar. İnişte bilet cüzdana, pasaporta ve dünya haritasına işlenir, mesafeyle üyelik kartları açılır. Proje tamamlandı ve arşivlendi; App Store'a çıkmadı. Kod MIT lisansıyla serbest: istediğin parçayı al, incele, devam ettir.

---

## What it does

**The ritual (start a flight)**
- **Plan:** choose a departure airport (about 4,000 real airports, searchable in English and Turkish) and a duration on a ruler. The app offers destinations whose realistic flight time matches that duration, drawn as a range ring on the map. "Surprise me" picks one for you.
- **Check in:** pick a seat on a seat map (the zone decides the window view), a cabin class and a scenario.
- **Print and tear:** a boarding pass prints from a ticket printer with synthesized thermal-printer sound, then you tear the stub off along the perforation with the trackpad (bendable paper, haptics, perforation-break sounds).
- **Gate and take-off:** the cruise camera starts low over the **real departure runway** (OurAirports runway data), the aircraft rolls, lifts off and the camera climbs out into a tilted, heading-up follow view while the plane turns onto its great-circle route.

**In flight**
- **Cruise map** on Apple Maps (standard, satellite, 3D) or an illustrated in-house engine, with a follow camera (heading up / north up, free camera after a drag, recenter), progress, ETA and phase timeline.
- **Window view:** a live scene from your seat: MapKit satellite ground, NASA GIBS cloud layer, day/night grading from the sun's real elevation along the route, wing, cabin lights and gentle motion.
- **Dashboard, pause, land early, meal-service break, descent warning and landing,** with cabin ambience and chimes (all sound is generated in code, see `docs/design/audio-credits.md`).
- **System surfaces:** menu bar popover, a floating mini map that stays on top, a second display as a seat-back TV, desktop widgets and notifications.
- **Soft focus enforcement:** a block list that warns when a distracting app comes to the front (no Accessibility permission, nothing is killed; ADR 0006).

**After landing**
- **Ticket wallet:** grid and stack views, four colour-by modes, filters, search, ticket detail with tilt, flip, notes and PNG share.
- **Passport** with stamps, **membership cards** in a coverflow that unlock with distance flown, an unlock moment.
- **Explore:** world map (globe / flat / replay of your flights), a stats bento, and a "year in flight" poster with PNG export.

**Also in the code**
- Onboarding, Settings (focus, sounds mixer, map engine, appearance), EN/TR string catalogues.
- **Pro / paywall** with StoreKit 2 (trial timeline, entitlements, feature gates). Product IDs were never registered in App Store Connect.
- **Together** (fly with friends: lobby, shared plane, passengers, group landing, public board). The UI and an in-memory service exist, but there is no backend, so it is hidden behind `TogetherAvailability.isVisible = false` in `App/Meridian/Features/Together/TogetherService.swift`.

## State at archive time

| Area | State |
|---|---|
| Core flight loop (plan → ritual → cruise → landing → wallet) | Works end to end |
| Collection (wallet, passport, cards, explore, stats) | Works |
| Menu bar, mini map, seat-back TV, widgets | Work |
| Persistence | SwiftData on disk; CloudKit sync is wired but turned off |
| Pro | Implemented against StoreKit 2, untested with real products |
| Together | UI + in-memory fake service only; no server; hidden |
| Pixel fidelity to the design canvas | Close on most screens, not exact everywhere |

## Building

Requirements: Xcode 27.1 or later, macOS 14+ (deployment target).

```sh
# the app
open App/Meridian.xcodeproj           # scheme "Meridian", run on "My Mac"
# or from the command line
xcodebuild -project App/Meridian.xcodeproj -scheme Meridian -destination 'platform=macOS' \
  -derivedDataPath .build-app build

# tests
cd Packages/MeridianCore && swift test   # any package under Packages/
# app tests: run the MeridianTests target in Xcode (⌘U)
```

To run on your own machine, change the bundle identifier (`app.meridian.Meridian`) and signing team in the project. Apple Maps and the GIBS cloud layer need network access; everything else works offline (airport and runway data are bundled).

## Layout

```
App/
  Meridian/                 the app target (SwiftUI + AppKit, Swift 6, MainActor by default)
    Features/<Feature>/      Audio, Cards, Cruise, Explore, Onboarding, Passport, Plan, Pro,
                             Ritual, Settings, Shell, States, System, Together, Wallet
    Debug/                   screenshot harness, screen registry, pointer simulation
  MeridianWidgets/          WidgetKit extension
  MeridianTests/            app-level tests (audio, cards …)
Packages/                   local SwiftPM packages, each with its own tests
  MeridianCore/             domain: airports, runways, geo maths, flights, timing rules (no Apple UI frameworks)
  MeridianPlan/             planning state, duration scrub, range ring
  MeridianCruise/           phase timeline, sun elevation, day/night grade, window camera and weather
  MeridianMaps/             Apple Maps surface, illustrated maps, globe, follow camera and gesture models
  MeridianData/             SwiftData schema and store
  MeridianFocus/            soft block list, frontmost-app watcher, Focus filter
  MeridianPro/              StoreKit 2 store, entitlements, paywall model
  MeridianUI/               design tokens, components, paper (boarding pass, printer, tear, cards, stamps, split-flap)
Scripts/                    data builders and screenshot / comparison tools
docs/                       PRD, ADRs, design notes, research
```

## Pieces worth borrowing

Even if you do not want a flight timer, some parts stand on their own:

- **`MeridianCore`**: a bundled, searchable airport index (OurAirports, public domain) with city aliases, great-circle maths, realistic flight-time estimates, and departure-runway selection.
- **`MeridianMaps/FollowCameraModel.swift`** and **`MapProjector`**: a navigation-style follow camera for MapKit on macOS (heading up, smooth easing, tilt that fades in near the ground, free/follow state machine), with overlays placed through MapKit's own perspective.
- **`MeridianCruise`**: sun elevation and a day/night colour grade along a moving route.
- **`App/Meridian/Features/Audio`**: an offline synthesizer (`MRCueRenderer`, `MRAmbientDSP`) that renders every UI sound and cabin ambience in code, with no samples.
- **`MeridianUI/Paper`**: SwiftUI paper components: a printing boarding pass, a tear-off stub that follows the perforation, tilting membership cards.
- **The screenshot harness** (`App/Meridian/Debug`, `Scripts/app-shot.sh`, `Scripts/sim-shot.sh`, `Scripts/compare.py`): render any registered screen of a sandboxed macOS app to a PNG from the command line, replay pointer scripts, and diff against a reference image.

## Documents

| | |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Product requirements: scope, domain rules, acceptance criteria, release plan |
| [`docs/decisions/`](docs/decisions) | Architecture decision records (native stack, computed progress, breaks, airport data …) |
| [`docs/design/IMPLEMENTATION.md`](docs/design/IMPLEMENTATION.md) | How the design was implemented and checked against references |
| [`docs/design/`](docs/design) | Design notes, audio API and credits, paper components, seat map; `export/` is an offline snapshot of the design canvas |
| [`docs/research/`](docs/research) | Competitor and App Store review research behind the PRD (Turkish) |

## Data and third-party assets

- Airports and runways: [OurAirports](https://ourairports.com/data/), public domain (`Scripts/build-airports.py`, `Scripts/build-runways.py`).
- Clouds in the window view: [NASA GIBS](https://www.earthdata.nasa.gov/gibs) imagery, fetched at runtime.
- Fonts: Inter, Barlow Condensed, JetBrains Mono, Newsreader, under the SIL Open Font License (licence files next to the fonts in `Packages/MeridianUI/Sources/MeridianUI/Resources/Fonts`).
- Sounds: all synthesized in code; no recordings.
- "Meridian" is a working name. The visual identity, names, art and sound are original; no competitor assets are in this repository.

## Licence

[MIT](LICENSE). Bundled fonts keep their own OFL licences, and OurAirports data is public domain.
