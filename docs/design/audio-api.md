# Audio API (`App/Meridian/Features/Audio/`)

Single surface: `MRSound.shared` (main actor). Source of the recipes: `docs/design/export/project/meridian-audio.js` (A01 / SoundSpec, Mixer, S52). PRD SND-1…4.

```swift
MRSound.shared.prewarm()                       // once at launch: renders the fixed cues in the background (SND-3)
MRSound.shared.play(.printerStep(3))           // fixed cues
MRSound.shared.play(.chime(.land))

MRSound.shared.rip.start()                     // paper rip, real-time
MRSound.shared.rip.set(0.6)                    // call on every drag event, v = drag velocity 0...1 (0 = silent)
MRSound.shared.rip.finish()                    // torn through: burst + 150 Hz thump  (or rip.stop() when released)

MRSound.shared.applyPreset(.nightFlight)       // .deepWork, .nightFlight, .rainyRead (MRSoundPreset.named("rain") = rainy)
MRSound.shared.setLevel(.rain, 0.4)            // layers: hum rain ocean forest brown pink music, 0...1
MRSound.shared.setMuted(.hum, true)
MRSound.shared.setMaster(0.7)
MRSound.shared.layersOff()                     // fade all out, stored levels kept; layersOn() or any setLevel brings them back

MRSound.shared.announce(.landingHeadsUp)       // recording if registered, else chime-only fallback; ducks ambient 6 dB
MRSound.shared.library.register(.captainWelcome, url: fileURL)
```

## Cues (`MRCue`)
`printerStep(Int)`, `paperSlide`, `tick(heavy:)`, `click`, `thump`, `stamp`, `chime(.board | .land)`, `seatbelt`, `whoosh`, `flap`, `ripFinish`, `crewChime` (the last one is new: the soft two-note crew chime that has no web recipe).
Same DSP parameters as the JS (oscillator types, frequencies, envelopes, filter Q, sends). Rendered once offline by `MRCueRenderer` into stereo buffers (FFT-convolved 1.3 s stereo noise IR, wet 0.55, master 0.85, compressor -16 dB 3:1), cached as `AVAudioPCMBuffer`, played from a pool of 8 `AVAudioPlayerNode`s. `printerStep(i)` is cached per index (clamped to 0...31).
Announcement-class cues (`chime`, `seatbelt`, `crewChime`) follow the Announcements switch; everything else follows UI sounds (A01).

## Live DSP
`MRAmbientDSP` (7 layers, one `AVAudioSourceNode`, per-layer smoothing tc 0.08 s, gain = level x master x k x 0.22, forest birds every 2.6 s, duck smoothing) and `MRRipDSP` (looped noise, band-pass 1.5-4 kHz following v, crackles 2-8 ms, level v^1.15 x 0.42). Parameters travel through an `OSAllocatedUnfairLock`; the render blocks never allocate on the audio thread except for crackle bookkeeping.
Deviation from the prototype: the forest bird chirps bypass the layer gain stage (in the JS they pass through it and are almost inaudible); their peak is 0.05 x level.

## Announcements
`Announcement` (`captainWelcome/Cruise/Descent`, `crewPhaseChime`, `seatbeltSign`, `landingHeadsUp`, `atcChatter`) with `group` (`AnnouncementGroup`: captain, crew, seatbelt, headsUp, atc; titles/subtitles copied from the Mixer artboard), `text` (script) and `fallbackCue`. No TTS and no bundled voice recordings (licensing). `AnnouncementLibrary` finds `Announcements/<rawValue>.(caf|m4a|wav|mp3)` in the bundle or a URL registered at runtime. Without a file: fallback chime (ATC: silence). Each group toggles independently (`settings.setEnabled(_:_:)`, ATC off by default); ducking dips ambient by 6 dB for the recording length (or the fallback chime) when `settings.duckAnnouncements`.

## Settings and system behavior (`MRSoundSettings`, UserDefaults, keys `meridian.sound.*`)
`uiSoundsEnabled`, `announcementsEnabled`, `enabledGroups`, `duckAnnouncements`, `allowDuringDoNotDisturb`, `master`, `layerLevels`, `mutedLayers`, `presetID`. `@Observable` for SwiftUI bindings.
- System volume and mute: the engine plays to the default output; the app never touches the hardware volume, so both are respected. Output-device changes restart the engine.
- Do Not Disturb: `MRFocusProbe` uses `INFocusStatusCenter` only if the user already authorized Focus Status (the app never requests it; macOS has no other public API). Unauthorized = treated as not active. Blocks cues, rip and announcements unless `allowDuringDoNotDisturb`; user-started ambient layers are not blocked. `MRSound.isDoNotDisturbActive` is overridable.

## Tests
`MRSound(settings:library:mode: .offline)` uses `AVAudioEngine.enableManualRenderingMode(.offline)` (no output device) and `renderOffline(seconds:)`. The app project has no test target and the pbxproj is owned elsewhere, so tests live in `App/MeridianTests/Audio/MRSoundTests.swift` and run with `Scripts/audio-test.sh` (throwaway SwiftPM package symlinking the sources, same MainActor default isolation). They check: every cue finite (no NaN), peak < 1 and audible, duration in `MRCue.expectedDuration`; FFT/envelope/biquad correctness; every layer and all layers together bounded; presets, layersOff, rip velocity gating, UI-sound/DND/announcement gating, settings persistence. If a test target is added later the same file works unchanged (`@testable import Meridian`). Cue rendering is slow in debug builds (a few seconds for the reverb cues); release is much faster and `prewarm()` does it off the main thread.
