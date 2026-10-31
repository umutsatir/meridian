# SeatMap (shared component)

`App/Meridian/Features/Together/SeatMap/SeatMap.swift`, from `SeatMap.dc.html`. Fixed design space 800 x 392 pt (`SeatMap.size`); scale it with `.scaleEffect(k, anchor: .topLeading)` inside a frame of `800k x 392k` (the lobby uses 0.7).

```swift
SeatMap(selectedSeat: "1A",          // highlighted seat, nil for none
        zone: "study",               // study | work | read | create, nil = no zone highlighted
        friends: [SeatMapFriend(seat: "1C", initial: "A", tintHex: "#FF8FB1", name: "Anna", presence: .atGate)],
        taken: ["2C", ...],          // unavailable seats (default = canvas set); friends' seats are never "taken"
        interactive: true,           // hover tooltip, click to pick, zone tabs clickable
        hoveredSeat: nil,            // pin the hover state (galleries)
        onSeat: { seat, zone in },   // fires on seat click and on zone-tab click
        onZone: { zone in })
```
- Presence of a friend: `.atGate`/`.inFlight` blue dot, `.idle` grey, `.landed` amber.
- Non-interactive (default) is for display (lobby). Seat circles use `SeatAvatar` (same file).
- S12 / S12B: use `interactive: true`, bind `onSeat`; pass the friends that already hold seats for the "sit together" variant.
- Not implemented: arrow-key navigation of the canvas (`focusSeat`); add with `onKeyPress` when the ritual screen needs it.
