# ADR 0007: Airport data bundled from OurAirports

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §7.6, research report §9

## Context

The Plan screen needs every destination offline, searchable in under 100 ms. OpenFlights route data is ODbL (attribution and share-alike obligations); OurAirports is public domain.

## Decision

`Scripts/build-airports.py` filters OurAirports `airports.csv` to airports with an IATA code, scheduled service and type large, medium or small (4,010 airports on 2026-10-30) and writes `Packages/MeridianCore/Sources/MeridianCore/Resources/airports.json` (about 650 KB). `AirportIndex.bundled()` loads it. Routes are never taken from a data set; they are computed from great-circle distance. The generated JSON is committed so builds need no network.

## Aliases and country names

OurAirports `municipality` is sometimes a district, not the city users expect (ADB is "Gaziemir", not "İzmir"; MXP is "Ferno", not "Milan"). `Resources/aliases.json` is a small, hand-curated map from IATA code to extra names (140 airports: city served, English and Turkish names such as "Londra", "Münih", "Kapadokya"). `AirportIndex.search` matches an alias like the city (prefix, then contains; case and diacritic insensitive), and folded search keys are computed once at init. The file is edited by hand, never generated, and a test checks that every key is a real airport. Only aliases that are certain go in; do not add guesses.

Country names are not stored. `Airport.countryName(locale:)` resolves the ISO code with `Locale.localizedString(forRegionCode:)`, which works in Foundation on all platforms.

## Consequences

- To refresh the airports: download `airports.csv`, run `python3 -I Scripts/build-airports.py airports.csv`, commit the diff, then re-check `aliases.json` still matches.
- Continents follow OurAirports (El Arish is Asia).
- Remaining gaps: aliases cover large and well-known airports only, not the long tail of medium and small ones; no non-Turkish, non-English local names (DE, JA, KO, ZH come with their localizations); airport names (not cities) are English as in the source.
