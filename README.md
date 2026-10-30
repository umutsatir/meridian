# Meridian

A native macOS focus timer where every session is a virtual flight. Pick a departure airport and a duration, check in, tear the stub off your boarding pass, and fly in real time while you work. Land to collect tickets, passport stamps and membership cards. Board the same plane as friends.

*Meridian is a working name.*

## Status

Pre-development. The product definition and design are ready; the first engineering milestone is a short technical spike (M0).

## Documents

| | |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Product requirements: scope, domain rules, requirements with acceptance criteria, release plan, open questions |
| [`docs/design/README.md`](docs/design/README.md) | Design source of truth (Claude Design canvas, 179 artboards) and how to use it |
| [`docs/design/claude-design-prompt.md`](docs/design/claude-design-prompt.md) | The prompt used to generate the design |
| [`docs/research/`](docs/research) | Competitor and review research behind the PRD |
| [`docs/decisions/`](docs/decisions) | Architecture decision records (ADRs) |

## Stack (planned)

Swift 6, SwiftUI + AppKit, MapKit, SwiftData + CloudKit, StoreKit 2, WidgetKit, AVAudioEngine. Pure-Swift domain logic lives in a package that builds and tests without Apple frameworks. A WebSocket backend for friends and public flights arrives in v1.5. See PRD §11.

## Requirements

macOS with Xcode 27.1 or later (development), macOS 14+ (deployment target, see PRD Q11).
