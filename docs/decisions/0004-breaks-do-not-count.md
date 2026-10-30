# ADR 0004: Break minutes never count as focus or distance (Q8)

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §7.4, §7.5, Q8

## Context

A meal break holds the clock and slides the ETA. If break time counted, users could earn miles by not working.

## Decision

Breaks (and pauses) are excluded from elapsed focus time. Credited distance is `routeDistanceKm × focusedFraction`; free flights credit `FlightTiming.km(forMinutes: focused)`. Breaks are allowed under every pause policy and have no length limit.

## Consequences

- Landing early during a break credits only the focus time before the break.
- Pause budget (Flexible, 10 minutes) and break time are tracked separately.
