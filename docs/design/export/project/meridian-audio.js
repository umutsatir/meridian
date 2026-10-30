/* Meridian sound engine — Web Audio recipes from §5.2. All sounds are synthesized; nothing is sampled.
   Usage: MeridianAudio.printerStep(i) · .paperSlide() · .tick() · .rip.start()/.rip.set(v)/.rip.stop() · .thump() · .stamp() · .chime('board'|'land') · .seatbelt() · .whoosh() · .click()
   A global flag (MeridianAudio.enabled) mirrors the "UI sounds" toggle. The context starts on the first user gesture. */
(function () {
  const A = { enabled: true, ctx: null, master: null, verb: null, noise: null, log: [] };
  A.init = function () {
    if (!A.ctx) {
      const C = window.AudioContext || window.webkitAudioContext; if (!C) return null;
      const c = A.ctx = new C();
      const comp = c.createDynamicsCompressor(); comp.threshold.value = -16; comp.ratio.value = 3;
      A.master = c.createGain(); A.master.gain.value = .85; A.master.connect(comp); comp.connect(c.destination);
      const n = c.sampleRate * 2, b = c.createBuffer(1, n, c.sampleRate), d = b.getChannelData(0);
      for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1; A.noise = b;
      // soft room: 1.3 s decaying stereo noise impulse
      const L = Math.floor(c.sampleRate * 1.3), ir = c.createBuffer(2, L, c.sampleRate);
      for (let ch = 0; ch < 2; ch++) { const x = ir.getChannelData(ch); for (let i = 0; i < L; i++) x[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / L, 2.6); }
      A.verb = c.createConvolver(); A.verb.buffer = ir; const vg = c.createGain(); vg.gain.value = .55; A.verb.connect(vg); vg.connect(A.master);
    }
    if (A.ctx.state === 'suspended') A.ctx.resume();
    return A.ctx;
  };
  const ok = () => A.enabled && A.init();
  const note = n => { A.log.push(n); if (A.log.length > 12) A.log.shift(); if (A.onSound) try { A.onSound(n); } catch (e) {} };
  const noiseSrc = (c, loop) => { const s = c.createBufferSource(); s.buffer = A.noise; s.loop = !!loop; return s; };
  const env = (g, t, a, peak, d, rel) => { g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(peak, t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d + rel); };
  const send = (node, amt) => { const c = A.ctx, g = c.createGain(); g.gain.value = amt; node.connect(g); g.connect(A.verb); };

  // Printer: square-wave stepper chirp (gated at ~60 Hz) + 3-5 kHz band-passed noise tick (20 ms) per step.
  A.printerStep = function (i, dur) {
    if (!ok()) return; const c = A.ctx, t = c.currentTime, D = (dur || .084);
    const o = c.createOscillator(); o.type = 'square'; o.frequency.setValueAtTime(170 + i * 5, t); o.frequency.linearRampToValueAtTime(240 + i * 6, t + D);
    const g = c.createGain(); g.gain.setValueAtTime(0, t);
    for (let k = 0; k * (1 / 60) < D; k++) { const s = t + k / 60; g.gain.setValueAtTime(.045, s); g.gain.setValueAtTime(.0, s + 1 / 120); }
    g.gain.setValueAtTime(0, t + D);
    const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1400; o.connect(lp); lp.connect(g); g.connect(A.master); o.start(t); o.stop(t + D + .02);
    const n = noiseSrc(c), bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 3600 + (i % 3) * 400; bp.Q.value = 1.4;
    const ng = c.createGain(); env(ng, t, .002, .09, .012, .01); n.connect(bp); bp.connect(ng); ng.connect(A.master); n.start(t, Math.random()); n.stop(t + .03);
    note('printer step ' + (i + 1));
  };
  // Paper sliding out: a quiet low-passed noise swell, ~1.6 s, a bed under the chirps
  A.paperSlide = function (len) {
    if (!ok()) return; const c = A.ctx, t = c.currentTime, L = len || 1.6;
    const n = noiseSrc(c, true), bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.setValueAtTime(900, t); bp.frequency.linearRampToValueAtTime(1500, t + L); bp.Q.value = .5;
    const g = c.createGain(); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(.05, t + .25); g.gain.setValueAtTime(.05, t + L - .2); g.gain.linearRampToValueAtTime(0, t + L);
    n.connect(bp); bp.connect(g); g.connect(A.master); n.start(t); n.stop(t + L + .05); note('paper slide');
  };
  A.tick = function (heavy) {
    if (!ok()) return; const c = A.ctx, t = c.currentTime;
    const o = c.createOscillator(); o.type = 'sine'; o.frequency.setValueAtTime(heavy ? 1500 : 2400, t); o.frequency.exponentialRampToValueAtTime(heavy ? 700 : 1400, t + .03);
    const g = c.createGain(); env(g, t, .001, heavy ? .12 : .06, .02, .03); o.connect(g); g.connect(A.master); o.start(t); o.stop(t + .08); note(heavy ? 'tick (heavy)' : 'tick');
  };
  A.click = function () {
    if (!ok()) return; const c = A.ctx, t = c.currentTime, n = noiseSrc(c), hp = c.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 2200;
    const g = c.createGain(); env(g, t, .001, .035, .006, .005); n.connect(hp); hp.connect(g); g.connect(A.master); n.start(t, Math.random()); n.stop(t + .02);
  };
  // Paper rip: white noise -> band-pass 1.5-4 kHz (Q .8) -> envelope driven by drag velocity; crackle clicks 2-8 ms; gate to 0 at rest.
  A.rip = {
    on: false,
    start() { if (!ok() || this.on) return; const c = A.ctx; this.n = noiseSrc(c, true); this.bp = c.createBiquadFilter(); this.bp.type = 'bandpass'; this.bp.frequency.value = 1800; this.bp.Q.value = .8;
      this.g = c.createGain(); this.g.gain.value = 0; this.n.connect(this.bp); this.bp.connect(this.g); this.g.connect(A.master); this.n.start(c.currentTime, Math.random()); this.on = true; this.v = 0; note('rip start'); },
    set(v) { if (!this.on) return; v = Math.max(0, Math.min(1, v)); this.v = v; const c = A.ctx, t = c.currentTime;
      this.g.gain.cancelScheduledValues(t); this.g.gain.setTargetAtTime(Math.pow(v, 1.15) * .42, t, .02); this.bp.frequency.setTargetAtTime(1500 + v * 2500, t, .03);
      const dens = v * 9; for (let k = 0; k < dens; k++) if (Math.random() < dens - k + .0) this.crackle(t + Math.random() * .016, v); },
    crackle(t, v) { const c = A.ctx, d = .002 + Math.random() * .006, s = noiseSrc(c), hp = c.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 1800 + Math.random() * 2400;
      const g = c.createGain(); env(g, t, .0005, .06 + v * .12, d, .002); s.connect(hp); hp.connect(g); g.connect(A.master); s.start(t, Math.random() * 1.8); s.stop(t + d + .01); },
    stop() { if (!this.on) return; const c = A.ctx, t = c.currentTime; this.g.gain.cancelScheduledValues(t); this.g.gain.setTargetAtTime(0, t, .012); try { this.n.stop(t + .08); } catch (e) {} this.on = false; note('rip stop'); },
    finish() { if (!ok()) return; const c = A.ctx, t = c.currentTime; if (!this.on) this.start(); this.bp.frequency.cancelScheduledValues(t); this.bp.frequency.setValueAtTime(1800, t); this.bp.frequency.linearRampToValueAtTime(4000, t + .2);
      this.g.gain.cancelScheduledValues(t); this.g.gain.setValueAtTime(.12, t); this.g.gain.linearRampToValueAtTime(.5, t + .18); this.g.gain.linearRampToValueAtTime(0, t + .24);
      for (let k = 0; k < 18; k++) this.crackle(t + k * .012, 1); const th = c.createOscillator(); th.type = 'sine'; th.frequency.value = 150; const tg = c.createGain(); env(tg, t + .2, .004, .3, .08, .1); th.connect(tg); tg.connect(A.master); th.start(t + .2); th.stop(t + .45);
      setTimeout(() => { this.stop(); }, 280); note('rip complete + 150 Hz thump'); }
  };
  A.thump = function () { // soft wallet thud
    if (!ok()) return; const c = A.ctx, t = c.currentTime, o = c.createOscillator(); o.type = 'sine'; o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(60, t + .12);
    const g = c.createGain(); env(g, t, .003, .3, .08, .12); o.connect(g); g.connect(A.master); o.start(t); o.stop(t + .3); note('wallet thud');
  };
  // Stamp: 80 -> 45 Hz sine drop over 120 ms + 3 ms noise click + room tail
  A.stamp = function () {
    if (!ok()) return; const c = A.ctx, t = c.currentTime, o = c.createOscillator(); o.type = 'sine'; o.frequency.setValueAtTime(80, t); o.frequency.exponentialRampToValueAtTime(45, t + .12);
    const g = c.createGain(); env(g, t, .002, .55, .1, .22); o.connect(g); g.connect(A.master); send(g, .35); o.start(t); o.stop(t + .5);
    const n = noiseSrc(c), bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 1400; bp.Q.value = .9; const ng = c.createGain(); env(ng, t, .0006, .22, .003, .004); n.connect(bp); bp.connect(ng); ng.connect(A.master); send(ng, .4); n.start(t, Math.random()); n.stop(t + .02); note('stamp thump');
  };
  const bell = (f, t, peak, dec) => { const c = A.ctx; [[1, 1], [2.76, .28], [5.4, .1]].forEach(p => { const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = f * p[0]; const g = c.createGain(); env(g, t, .006, peak * p[1], dec * (p[0] > 1 ? .55 : 1), .1); o.connect(g); g.connect(A.master); send(g, .5); o.start(t); o.stop(t + dec + .4); }); };
  A.chime = function (kind) { // three-note bell: C5 E5 G5 ascending (boarding) / reversed (landing)
    if (!ok()) return; const t = A.ctx.currentTime, N = kind === 'land' ? [783.99, 659.25, 523.25] : [523.25, 659.25, 783.99];
    N.forEach((f, i) => bell(f, t + i * .22, .16, 1.9)); note(kind === 'land' ? 'landing chime G5-E5-C5' : 'boarding chime C5-E5-G5');
  };
  A.seatbelt = function () { // two sine tones 880 then 660, 180 ms each
    if (!ok()) return; const c = A.ctx, t = c.currentTime;[[880, 0], [660, .2]].forEach(p => { const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = p[0]; const g = c.createGain(); env(g, t + p[1], .012, .13, .12, .14); o.connect(g); g.connect(A.master); send(g, .55); o.start(t + p[1]); o.stop(t + p[1] + .45); });
    note('seatbelt chime 880/660');
  };
  A.whoosh = function () { // card flip: filtered noise sweep 400 -> 1200 Hz, 250 ms
    if (!ok()) return; const c = A.ctx, t = c.currentTime, n = noiseSrc(c), bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.Q.value = 1.1; bp.frequency.setValueAtTime(400, t); bp.frequency.exponentialRampToValueAtTime(1200, t + .25);
    const g = c.createGain(); env(g, t, .06, .12, .1, .12); n.connect(bp); bp.connect(g); g.connect(A.master); n.start(t, Math.random()); n.stop(t + .3); note('whoosh 400→1200 Hz');
  };
  A.flap = function () { // split-flap clack
    if (!ok()) return; const c = A.ctx, t = c.currentTime, n = noiseSrc(c), bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 2600; bp.Q.value = 2.2;
    const g = c.createGain(); env(g, t, .0008, .07, .006, .008); n.connect(bp); bp.connect(g); g.connect(A.master); n.start(t, Math.random() * 1.8); n.stop(t + .03);
  };
  // Ambient layers for the mixer: name -> {set(level 0..1)}
  const layers = {};
  A.layer = function (name, level) {
    if (!A.enabled || !A.init()) return; const c = A.ctx;
    if (!layers[name]) {
      const g = c.createGain(); g.gain.value = 0; g.connect(A.master); const L = { g, nodes: [] };
      const mk = (type, f, q) => { const b = c.createBiquadFilter(); b.type = type; b.frequency.value = f; if (q) b.Q.value = q; return b; };
      if (name === 'hum') { const n = noiseSrc(c, true), lp = mk('lowpass', 190), lp2 = mk('lowpass', 120); n.connect(lp); lp.connect(lp2); lp2.connect(g); n.start(); L.nodes.push(n); L.k = 1.6; const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = 58; const og = c.createGain(); og.gain.value = .05; const ol = mk('lowpass', 160); o.connect(ol); ol.connect(og); og.connect(g); o.start(); L.nodes.push(o); }
      if (name === 'rain') { const n = noiseSrc(c, true), hp = mk('highpass', 1200), bp = mk('bandpass', 5200, .4); n.connect(hp); hp.connect(bp); bp.connect(g); n.start(); L.nodes.push(n); L.k = .5; }
      if (name === 'ocean') { const n = noiseSrc(c, true), lp = mk('lowpass', 520); n.connect(lp); const sw = c.createGain(); sw.gain.value = .5; lp.connect(sw); sw.connect(g); const l = c.createOscillator(); l.frequency.value = .11; const lg = c.createGain(); lg.gain.value = .45; l.connect(lg); lg.connect(sw.gain); n.start(); l.start(); L.nodes.push(n, l); L.k = 1.3; }
      if (name === 'forest') { const n = noiseSrc(c, true), bp = mk('bandpass', 2400, .35); n.connect(bp); const q = c.createGain(); q.gain.value = .35; bp.connect(q); q.connect(g); n.start(); L.nodes.push(n); L.k = .3; L.bird = setInterval(() => { if (!layers.forest || layers.forest.lv < .02) return; const t = c.currentTime, o = c.createOscillator(); o.type = 'sine'; const f0 = 2600 + Math.random() * 1500; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f0 * 1.35, t + .08); o.frequency.exponentialRampToValueAtTime(f0 * .9, t + .16); const bg = c.createGain(); env(bg, t, .01, .05 * layers.forest.lv, .1, .08); o.connect(bg); bg.connect(g); o.start(t); o.stop(t + .3); }, 2600); }
      if (name === 'brown') { const n = noiseSrc(c, true), lp = mk('lowpass', 420); n.connect(lp); lp.connect(g); n.start(); L.nodes.push(n); L.k = 1.8; }
      if (name === 'pink') { const n = noiseSrc(c, true), lp = mk('lowpass', 2600); n.connect(lp); lp.connect(g); n.start(); L.nodes.push(n); L.k = .4; }
      if (name === 'music') { const lp = mk('lowpass', 900); lp.connect(g);[261.63, 329.63, 392, 493.88, 587.33].forEach((f, i) => { const o = c.createOscillator(); o.type = i % 2 ? 'triangle' : 'sine'; o.frequency.value = f; o.detune.value = (i - 2) * 4; const og = c.createGain(); og.gain.value = .05; const lf = c.createOscillator(); lf.frequency.value = .05 + i * .021; const lg = c.createGain(); lg.gain.value = .03; lf.connect(lg); lg.connect(og.gain); o.connect(og); og.connect(lp); o.start(); lf.start(); L.nodes.push(o, lf); }); L.k = 1.2; }
      layers[name] = L; L.lv = 0;
    }
    const L = layers[name]; L.lv = level; L.g.gain.setTargetAtTime(level * (L.k || 1) * .22, c.currentTime, .08);
  };
  A.layersOff = function () { Object.keys(layers).forEach(k => { layers[k].lv = 0; layers[k].g.gain.setTargetAtTime(0, A.ctx.currentTime, .05); }); };
  window.MeridianAudio = A;
})();
