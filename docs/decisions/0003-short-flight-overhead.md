# ADR 0003: Short-flight overhead scales with duration (Q10)

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §7.1, Q10, ADR 0008

## Context

The base formula `minutes = 15 + km / 12.9` gives zero distance for durations of 15 minutes or less, so 10-minute flights would have no destinations.

## Decision

Use `overhead(d) = min(15, d / 2)`. Below 30 minutes: `km = d / 2 × 12.9` (10 min ≈ 64.5 km, 20 min ≈ 129 km). From 30 minutes up: `km = (d − 15) × 12.9`. The regimes meet at 30 minutes / 193.5 km, so the function is continuous and LHR→CDG (348 km) is still 42 minutes. Implemented in `FlightTiming`.

## Consequences

- Every duration from 10 minutes has a non-empty range ring in dense regions; sparse regions may still have no match inside ±3 minutes, which the UI must handle.
- Distance and minutes round-trip for the supported durations (tested).

## Update (ADR 0008)

The minimum flight duration is now 30 minutes, so the short regime (below 30 minutes) is **not reachable from the UI**. It stays in `FlightTiming` and its tests because the formula must remain continuous and total.
