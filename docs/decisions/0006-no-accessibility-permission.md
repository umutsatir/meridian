# ADR 0006: No Accessibility permission in v1 (Q12)

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §9.11, §13, Q12

## Context

Soft blocking needs to know the frontmost app. `NSWorkspace` activation notifications provide that without the Accessibility permission, which hurts onboarding and App Review.

## Decision

Do not request Accessibility in v1. Detect the frontmost app with `NSWorkspace`. Ask for the permission only if a later feature needs window titles, with an explanation before the system prompt.

## Consequences

- The onboarding permission step covers Notifications and the Focus filter only.
- Blocking by website or window title is not possible in v1.
