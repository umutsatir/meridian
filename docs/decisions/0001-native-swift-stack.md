# ADR 0001: Native Swift stack

- **Status:** Accepted
- **Date:** 2026-10-30
- **Related:** PRD §11, research report §5

## Context

The product's value is in MapKit 3D, menu bar, WidgetKit, iCloud, StoreKit and low energy use. Research flagged battery and heat as a top complaint of the category leader. Cross-platform stacks (React Native macOS, Tauri, Electron) would still need Swift for most of these parts.

## Decision

Build the app in Swift 6 with SwiftUI and AppKit bridges. Keep domain logic in a pure-Swift package, `MeridianCore`, with no Apple-framework dependency so it builds and tests anywhere Swift runs.

## Consequences

- Web and Android clients are out of scope; shared pieces (Together backend, landing pages) may use web technology.
- iPhone and iPad companions stay cheap because `MeridianCore` and `MeridianUI` are multiplatform.
- `MeridianCore` declares macOS 14 and iOS 17 so it can be reused later.
