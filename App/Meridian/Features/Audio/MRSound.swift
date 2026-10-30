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
    private(set) var ambientEnabled = false

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var players: [AVAudioPlayerNode] = []
    private var busy: [Bool] = []
    private var voice: AVAudioPlayerNode?
    private let ambient: MRAmbientDSP
    fileprivate let ripDSP: MRRipDSP
    private var cache: [MRCue: AVAudioPCMBuffer] = [:]
    private var started = false
    private var duckToken = 0
    private var observer: NSObjectProtocol?
    private var prewarmTask: Task<Void, Never>?
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
        let b = Self.pcm(MRCueRenderer.render(key))
        cache[key] = b
        return b
    }
    /// Printer steps beyond the 14 of the check-in animation share one buffer.
    private static func cacheKey(_ cue: MRCue) -> MRCue {
        if case .printerStep(let i) = cue { return .printerStep(min(max(i, 0), 31)) }
        return cue
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

    func level(of layer: MRLayer) -> Double { settings.level(of: layer) }

    /// Sets a layer level 0...1 and turns the mixer on.
    func setLevel(_ layer: MRLayer, _ level: Double) {
        settings.layerLevels[layer] = min(1, max(0, level))
        settings.presetID = nil
        resumeAmbient()
    }
    func setMuted(_ layer: MRLayer, _ muted: Bool) {
        if muted { settings.mutedLayers.insert(layer) } else { settings.mutedLayers.remove(layer) }
        resumeAmbient()
    }
    func setMaster(_ master: Double) {
        settings.master = min(1, max(0, master))
        resumeAmbient()
    }
    func applyPreset(_ preset: MRSoundPreset) {
        settings.layerLevels = preset.levels
        settings.master = preset.master
        settings.mutedLayers = []
        settings.presetID = preset.id
        resumeAmbient()
    }
    /// Fades every layer to silence (keeps the stored levels); any later layer or preset change brings them back.
    func layersOff() {
        ambientEnabled = false
        applyLayerParams(fast: true)
    }
    func layersOn() { resumeAmbient() }

    private func resumeAmbient() {
        ambientEnabled = true
        applyLayerParams()
        if (anyAudibleLayer) { _ = startIfNeeded() }
    }
    private var anyAudibleLayer: Bool { MRLayer.allCases.contains { !settings.mutedLayers.contains($0) && settings.level(of: $0) > 0 } && settings.master > 0 }

    private func applyLayerParams(fast: Bool = false) {
        let snapshot = (levels: settings.layerLevels, muted: settings.mutedLayers, master: settings.master, on: ambientEnabled)
        ambient.update { p in
            for l in MRLayer.allCases {
                let lv = snapshot.on && !snapshot.muted.contains(l) ? (snapshot.levels[l] ?? 0) * snapshot.master : 0
                p.level[l.index] = lv
                p.gain[l.index] = lv * l.k * 0.22
                p.tc[l.index] = fast ? 0.05 : 0.08
            }
        }
    }

    // MARK: Engine

    @discardableResult
    func startIfNeeded() -> Bool {
        if started { return isAvailable }
        started = true
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
        do {
            if mode == .offline {
                try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            }
            engine.prepare()
            try engine.start()
        } catch {
            isAvailable = false
            return false
        }
        if mode == .live {
            observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { try? self?.engine.start() }
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
