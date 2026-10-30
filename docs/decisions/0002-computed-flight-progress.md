# ADR 0002: Flight progress is computed, never ticked

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §7.2, §10.2

## Context

Competitor reviews report flights that reset after sleep, restart or crash. A timer-driven model loses state whenever the process stops.

## Decision

A `Flight` stores `startedAt`, closed pause and break totals, and at most one open hold. Elapsed time is `now − startedAt − held time`. `settle(at:)` lands a finished flight and can be called on launch, wake and every tick; it is idempotent and dates the landing at the moment focus time reached the duration, not at `now`. Flexible pauses stop counting by themselves once the 10-minute budget is spent.

## Consequences

- Quit, sleep and crash cannot change the result.
- The UI calls `settle` on launch and on `NSWorkspace.didWakeNotification` and shows the Flight resumed banner.
- All time-dependent logic takes `now` as a parameter, so it is tested without a clock.
