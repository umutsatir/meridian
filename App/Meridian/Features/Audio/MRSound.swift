import AVFoundation
import Foundation

// MARK: - MRSound: the single audio surface of the app. See docs/design/audio-api.md.
//
//   MRSound.shared.play(.printerStep(3))
//   MRSound.shared.rip.start(); MRSound.shared.rip.set(0.6); MRSound.shared.rip.finish()
//   MRSound.shared.applyPreset(.nightFlight); MRSound.shared.setLevel(.rain, 0.4)
//   MRSound.shared.announce(.landingHeadsUp)

@MainActor
final class MRSound {
    enum Mode: Sendable {
        /// Plays through the default output device (follows the system volume and mute).
        case live
        /// Renders into memory with `AVAudioEngine.enableManualRenderingMode(.offline)`; no output device (tests, CI).
        case offline
    }

    static let shared = MRSound()

    let settings: MRSoundSettings
    let library: AnnouncementLibrary
    let mode: Mode
    private(set) var rip: MRRip!

    /// Overridable for tests; defaults to the Focus probe.
    var isDoNotDisturbActive: () -> Bool = { MRFocusProbe.isDoNotDisturbActive() }

    /// False when the engine could not start (no output device).
    private(set) var isAvailable = true
    /// True while a flight is in progress (set by `setFlightActive`). The cabin bed only plays during a flight.
    private(set) var flightActive = false
    /// The cabin bed is meant to be audible: a flight is running and the user has not switched cabin sound off.
    var ambientEnabled: Bool { flightActive && settings.cabinSoundEnabled }

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var players: [AVAudioPlayerNode] = []
    private var busy: [Bool] = []
    private var voice: AVAudioPlayerNode?
    private let ambient: MRAmbientDSP
    fileprivate let ripDSP: MRRipDSP
    private var cache: [MRCue: AVAudioPCMBuffer] = [:]
    private var graphBuilt = false
    private var duckToken = 0
    private var observer: NSObjectProtocol?
    private var prewarmTask: Task<Void, Never>?
    /// Current parameters of the ambient bed (diagnostics, tests).
    var ambientParams: MRAmbientDSP.Params { ambient.currentParams() }
    /// Last played cues (diagnostic, like `A.log` of the prototype).
    private(set) var recentCues: [MRCue] = []

    static let poolSize = 8
    static let outputSampleRate = MRCueRenderer.sampleRate

    init(settings: MRSoundSettings = MRSoundSettings(), library: AnnouncementLibrary = AnnouncementLibrary(), mode: Mode = .live) {
        self.settings = settings
        self.library = library
        self.mode = mode
        let sr = Self.outputSampleRate
        format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sr, channels: 2, interleaved: false)!
        ambient = MRAmbientDSP(sampleRate: sr)
        ripDSP = MRRipDSP(sampleRate: sr)
        rip = MRRip(sound: self, dsp: ripDSP)
        applyLayerParams()
    }

    // MARK: Gating (SND-4)

    /// Whether UI sounds may play right now (UI sounds switch and Do Not Disturb).
    var uiSoundsAllowed: Bool { settings.uiSoundsEnabled && !blockedByDND }
    func announcementAllowed(_ a: Announcement) -> Bool {
        settings.announcementsEnabled && settings.isEnabled(a.group) && !blockedByDND
    }
    private var blockedByDND: Bool { !settings.allowDuringDoNotDisturb && isDoNotDisturbActive() }
    private func allowed(_ cue: MRCue) -> Bool {
        cue.isAnnouncementClass ? (settings.announcementsEnabled && !blockedByDND) : uiSoundsAllowed
    }

    // MARK: Cues

    /// Plays a fixed sound. Silently ignored when the switch for its class is off or Do Not Disturb applies.
    func play(_ cue: MRCue) {
        guard allowed(cue) else { return }
        playUngated(cue)
    }

    func playUngated(_ cue: MRCue) {
        guard startIfNeeded() else { return }
        let buffer = buffer(for: cue)
        recentCues.append(cue); if recentCues.count > 12 { recentCues.removeFirst() }
        let i = busy.firstIndex(of: false) ?? 0
        let node = players[i]
        if busy[i] { node.stop() }
        busy[i] = true
        node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.cueFinished(i) }
        }
        node.play()
    }

    private func cueFinished(_ i: Int) {
        guard i < busy.count else { return }
        busy[i] = false
        players[i].stop()
    }

    private func buffer(for cue: MRCue) -> AVAudioPCMBuffer {
        let key = Self.cacheKey(cue)
        if let b = cache[key] { return b }
        let b: AVAudioPCMBuffer
        if case .chime(let kind) = key, let url = library.chimeFile(kind), let file = Self.loadChime(url, sampleRate: format.sampleRate) {
            b = Self.pcm(file)
        } else {
            b = Self.pcm(MRCueRenderer.render(key))
        }
        cache[key] = b
        return b
    }
    /// Printer steps beyond the 14 of the check-in animation share one buffer.
    private static func cacheKey(_ cue: MRCue) -> MRCue {
        if case .printerStep(let i) = cue { return .printerStep(min(max(i, 0), 31)) }
        return cue
    }

    /// Reads a short chime recording (<= 3 s are kept), converts it to the engine format and adds click-free edges.
    nonisolated static func loadChime(_ url: URL, sampleRate: Double) -> MRStereoBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let outFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false),
              let conv = AVAudioConverter(from: file.processingFormat, to: outFmt) else { return nil }
        let maxIn = AVAudioFrameCount(min(Double(file.length), 3.0 * file.processingFormat.sampleRate))
        guard maxIn > 0, let inBuf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: maxIn),
              (try? file.read(into: inBuf, frameCount: maxIn)) != nil else { return nil }
        let cap = AVAudioFrameCount(Double(inBuf.frameLength) * sampleRate / file.processingFormat.sampleRate) + 1024
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: cap) else { return nil }
        var fed = false
        var err: NSError?
        conv.convert(to: outBuf, error: &err) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return inBuf
        }
        guard err == nil, outBuf.frameLength > 0, let c = outBuf.floatChannelData else { return nil }
        let n = Int(outBuf.frameLength)
        var b = MRStereoBuffer(left: Array(UnsafeBufferPointer(start: c[0], count: n)),
                               right: Array(UnsafeBufferPointer(start: c[1], count: n)), sampleRate: sampleRate)
        var peak = b.peak
        if peak > 0.9 { let k = 0.9 / peak; for i in 0..<n { b.left[i] *= k; b.right[i] *= k }; peak = 0.9 }
        MRCueRenderer.edgeFade(&b, fadeIn: 0.005, fadeOut: 0.25)
        return b.hasNonFinite ? nil : b
    }

    nonisolated static func pcm(_ s: MRStereoBuffer) -> AVAudioPCMBuffer {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: s.sampleRate, channels: 2, interleaved: false)!
        let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(s.frames))!
        b.frameLength = AVAudioFrameCount(s.frames)
        s.left.withUnsafeBufferPointer { b.floatChannelData![0].update(from: $0.baseAddress!, count: s.frames) }
        s.right.withUnsafeBufferPointer { b.floatChannelData![1].update(from: $0.baseAddress!, count: s.frames) }
        return b
    }

    /// Renders the common cues in the background so the first tap never stalls (SND-3: rendered once).
    func prewarm() {
        guard prewarmTask == nil else { return }
        let cues: [MRCue] = [.stamp, .chime(.board), .chime(.land), .seatbelt, .thump, .whoosh, .flap, .click,
                             .tick(heavy: false), .tick(heavy: true), .paperSlide, .ripFinish, .crewChime]
                          + (0..<14).map { MRCue.printerStep($0) }
        prewarmTask = Task {
            for cue in cues where cache[cue] == nil {
                if case .chime(let k) = cue, library.chimeFile(k) != nil { _ = buffer(for: cue); continue }
                let rendered = await Task.detached(priority: .utility) { MRCueRenderer.render(cue) }.value
                if cache[cue] == nil { cache[cue] = Self.pcm(rendered) }
            }
        }
    }

    // MARK: Announcements

    /// Plays an announcement: its registered recording, otherwise the chime-only fallback. Ducks ambient layers.
    func announce(_ announcement: Announcement) {
        guard announcementAllowed(announcement) else { return }
        guard startIfNeeded() else { return }
        if let url = library.recording(for: announcement), let file = try? AVAudioFile(forReading: url) {
            let duration = Double(file.length) / file.processingFormat.sampleRate
            let node = voiceNode(for: file.processingFormat)
            node.stop()
            node.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in }
            node.play()
            duck(for: duration + 0.2)
        } else if let cue = announcement.fallbackCue {
            playUngated(cue)
            duck(for: min(cue.expectedDuration.lowerBound, 2.0))
        }
    }

    private func voiceNode(for fmt: AVAudioFormat) -> AVAudioPlayerNode {
        if let v = voice, v.outputFormat(forBus: 0).sampleRate == fmt.sampleRate, v.outputFormat(forBus: 0).channelCount == fmt.channelCount { return v }
        if let v = voice { engine.disconnectNodeOutput(v); engine.detach(v) }
        let v = AVAudioPlayerNode()
        engine.attach(v)
        engine.connect(v, to: engine.mainMixerNode, format: fmt)
        voice = v
        return v
    }

    private func duck(for seconds: Double) {
        guard settings.duckAnnouncements else { return }
        duckToken += 1
        let token = duckToken
        ambient.update { $0.duck = 0.5 }   // -6 dB
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, self.duckToken == token else { return }
            self.ambient.update { $0.duck = 1 }
        }
    }

    // MARK: Ambient layers (SND-1)
    //
    // The cabin bed plays only during a flight (`setFlightActive`, driven by AppModel.activeFlight) and only while the user
    // keeps "Cabin sound" on (default on). It fades in over 1.8 s and out over 1.5 s (equal power). Level, mute and master
    // changes ramp in about 0.4 s. The engine itself is never stopped, so nothing is cut off.

    func level(of layer: MRLayer) -> Double { settings.level(of: layer) }

    /// A flight started (true) or ended / landed / was cancelled / deleted (false).
    func setFlightActive(_ active: Bool) {
        guard active != flightActive else { return }
        flightActive = active
        syncAmbient()
    }

    /// The user's cabin sound switch (Settings > Sounds, the cruise sound button). Remembered.
    func setCabinSound(_ on: Bool) {
        settings.cabinSoundEnabled = on
        syncAmbient()
    }

    /// Sets a layer level 0...1.
    func setLevel(_ layer: MRLayer, _ level: Double) {
        settings.layerLevels[layer] = min(1, max(0, level))
        settings.presetID = nil
        applyLayerParams()
    }
    func setMuted(_ layer: MRLayer, _ muted: Bool) {
        if muted { settings.mutedLayers.insert(layer) } else { settings.mutedLayers.remove(layer) }
        applyLayerParams()
    }
    func setMaster(_ master: Double) {
        settings.master = min(1, max(0, master))
        applyLayerParams()
    }
    func applyPreset(_ preset: MRSoundPreset) {
        settings.layerLevels = preset.levels
        settings.master = preset.master
        settings.mutedLayers = []
        settings.presetID = preset.id
        applyLayerParams()
    }
    /// Pushes the whole mixer state (Settings > Sounds) without changing whether the bed is on.
    func setMixer(levels: [MRLayer: Double], muted: Set<MRLayer>, master: Double) {
        settings.layerLevels = levels.mapValues { min(1, max(0, $0)) }
        settings.mutedLayers = muted
        settings.master = min(1, max(0, master))
        applyLayerParams()
    }
    /// Fades the bed out (stored levels kept). Same as `setCabinSound(false)`.
    func layersOff() { setCabinSound(false) }
    func layersOn() { setCabinSound(true) }

    private func syncAmbient() {
        let on = ambientEnabled
        applyLayerParams()
        ambient.update { $0.fadeTarget = on ? 1 : 0; $0.fadeSeconds = on ? MRFade.ambientIn : MRFade.ambientOut }
        if on { _ = startIfNeeded() }
    }

    private func applyLayerParams() {
        let snapshot = (levels: settings.layerLevels, muted: settings.mutedLayers, master: settings.master)
        ambient.update { p in
            for l in MRLayer.allCases {
                let lv = !snapshot.muted.contains(l) ? (snapshot.levels[l] ?? 0) * snapshot.master : 0
                p.level[l.index] = lv
                p.gain[l.index] = lv * l.k * 0.22
                p.tc[l.index] = 0.13
            }
        }
    }

    // MARK: Engine

    /// Builds the graph once and starts the engine; retried on the next call when the first start failed (no device yet).
    @discardableResult
    func startIfNeeded() -> Bool {
        if !graphBuilt {
            let node = ambient.makeNode(format: format)
            let ripNode = ripDSP.makeNode(format: format)
            engine.attach(node); engine.attach(ripNode)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.connect(ripNode, to: engine.mainMixerNode, format: format)
            for _ in 0..<Self.poolSize {
                let p = AVAudioPlayerNode()
                engine.attach(p)
                engine.connect(p, to: engine.mainMixerNode, format: format)
                players.append(p); busy.append(false)
            }
            if mode == .offline {
                do { try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096) }
                catch { isAvailable = false; return false }
            }
            graphBuilt = true
        }
        if engine.isRunning { return true }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            isAvailable = false
            return false
        }
        isAvailable = true
        if mode == .live, observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.startIfNeeded() }
            }
        }
        return true
    }

    // MARK: Offline rendering (tests, CI)

    /// Pulls `seconds` of the mixed output from an engine created with `mode: .offline`.
    func renderOffline(seconds: Double) -> MRStereoBuffer? {
        guard mode == .offline, startIfNeeded() else { return nil }
        let total = Int(seconds * format.sampleRate)
        let chunk = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
        var l: [Float] = [], r: [Float] = []
        l.reserveCapacity(total); r.reserveCapacity(total)
        while l.count < total {
            let n = AVAudioFrameCount(min(4096, total - l.count))
            guard let status = try? engine.renderOffline(n, to: chunk), status == .success else { break }
            let c = chunk.floatChannelData!
            l.append(contentsOf: UnsafeBufferPointer(start: c[0], count: Int(chunk.frameLength)))
            r.append(contentsOf: UnsafeBufferPointer(start: c[1], count: Int(chunk.frameLength)))
        }
        return MRStereoBuffer(left: l, right: r, sampleRate: format.sampleRate)
    }
}

// MARK: - Rip

/// Interactive paper rip: sound and tone follow the drag velocity (0...1). Silent at zero velocity.
///
///     rip.start(); rip.set(v) /* on every drag event */; rip.finish() /* torn through */ or rip.stop() /* released */
@MainActor
final class MRRip {
    private unowned let sound: MRSound
    private let dsp: MRRipDSP
    private var rng = MRRandom(seed: UInt64(truncatingIfNeeded: Date().timeIntervalSince1970.bitPattern))
    private(set) var isActive = false
    private(set) var velocity = 0.0

    fileprivate init(sound: MRSound, dsp: MRRipDSP) { self.sound = sound; self.dsp = dsp }

    func start() {
        guard !isActive, sound.uiSoundsAllowed, sound.startIfNeeded() else { return }
        isActive = true; velocity = 0
        dsp.update { $0.gain = 0; $0.gainTc = 0.02; $0.pending.removeAll() }
    }

    /// Drag velocity 0...1: level = v^1.15 x 0.42, band-pass centre 1.5...4 kHz, crackle density up to 9 per call.
    func set(_ v: Double) {
        guard isActive else { return }
        let v = min(1, max(0, v)); velocity = v
        var crackles: [MRRipDSP.Crackle] = []
        let sr = dsp.sampleRate, dens = v * 9
        var k = 0.0
        while k < dens {
            if rng.next() < dens - k {
                crackles.append(.init(delay: Int(rng.next() * 0.016 * sr), duration: 0.002 + rng.next() * 0.006,
                                      highpass: 1800 + rng.next() * 2400, peak: 0.06 + v * 0.12,
                                      noiseOffset: Int(rng.next() * 1.8 * sr)))
            }
            k += 1
        }
        dsp.update {
            $0.gain = pow(v, 1.15) * 0.42; $0.gainTc = 0.02
            $0.bandHz = 1500 + v * 2500; $0.bandTc = 0.03
            $0.pending.append(contentsOf: crackles)
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false; velocity = 0
        dsp.update { $0.gain = 0; $0.gainTc = 0.012 }
    }

    /// The paper tears through: stops the live rip and plays the completion burst with its 150 Hz thump.
    func finish() {
        stop()
        sound.play(.ripFinish)
    }
}
