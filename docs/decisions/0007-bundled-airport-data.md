# ADR 0007: Airport data bundled from OurAirports

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §7.6, research report §9

## Context

The Plan screen needs every destination offline, searchable in under 100 ms. OpenFlights route data is ODbL (attribution and share-alike obligations); OurAirports is public domain.

## Decision

`Scripts/build-airports.py` filters OurAirports `airports.csv` to airports with an IATA code, scheduled service and type large, medium or small (4,010 airports on 2026-10-30) and writes `Packages/MeridianCore/Sources/MeridianCore/Resources/airports.json` (about 650 KB). `AirportIndex.bundled()` loads it. Routes are never taken from a data set; they are computed from great-circle distance. The generated JSON is committed so builds need no network.

## Consequences

- To refresh: download `airports.csv`, run `python3 -I Scripts/build-airports.py airports.csv`, commit the diff.
- OurAirports `municipality` is sometimes a district, not the city the user expects (ADB is "Gaziemir", not "İzmir"). Search and tickets will show that until localized city names and aliases are added (PRD §7.6 says names are localized); this is a known gap, not a bug in `AirportIndex.search`.
- Continents follow OurAirports (El Arish is Asia).
- Country names are not in the file yet; only ISO codes.
