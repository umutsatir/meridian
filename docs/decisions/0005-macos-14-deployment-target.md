# ADR 0005: macOS 14 deployment target (Q11)

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §11.1, Q11

## Context

The category leader supports macOS 14+. Liquid Glass is a macOS 26 feature.

## Decision

Target macOS 14. Use Liquid Glass materials through `#available` on macOS 26 and a solid or material fallback below.

## Consequences

- Two visual paths to test.
- Raising the target later is a one-line change per package.
