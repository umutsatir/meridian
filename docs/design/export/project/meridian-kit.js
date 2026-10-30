/* Meridian kit: sample data + pure helpers shared by artboards (no UI). */
(function () {
  // iata: [city, airport name, country code, lat, lon]
  var A = {
    LHR:['London','London Heathrow','GB',51.4700,-0.4543], LGW:['London','London Gatwick','GB',51.1537,-0.1821],
    STN:['London','London Stansted','GB',51.8860,0.2389], LTN:['London','London Luton','GB',51.8747,-0.3683],
    LCY:['London','London City','GB',51.5053,0.0553], BHX:['Birmingham','Birmingham','GB',52.4539,-1.7480],
    MAN:['Manchester','Manchester','GB',53.3537,-2.2750], LPL:['Liverpool','Liverpool John Lennon','GB',53.3336,-2.8497],
    LBA:['Leeds','Leeds Bradford','GB',53.8659,-1.6606], MME:['Teesside','Teesside International','GB',54.5092,-1.4294],
    BLK:['Blackpool','Blackpool','GB',53.7717,-3.0286], VLY:['Anglesey','Anglesey','GB',53.2481,-4.5353],
    NQY:['Newquay','Cornwall Airport Newquay','GB',50.4406,-4.9954], EDI:['Edinburgh','Edinburgh','GB',55.9500,-3.3725],
    GLA:['Glasgow','Glasgow','GB',55.8719,-4.4331], BRS:['Bristol','Bristol','GB',51.3827,-2.7191],
    SOU:['Southampton','Southampton','GB',50.9503,-1.3568], EXT:['Exeter','Exeter','GB',50.7344,-3.4139],
    NWI:['Norwich','Norwich','GB',52.6758,1.2828], EMA:['Nottingham','East Midlands','GB',52.8311,-1.3281],
    NCL:['Newcastle','Newcastle','GB',55.0375,-1.6917], BFS:['Belfast','Belfast International','GB',54.6575,-6.2158],
    JER:['Jersey','Jersey','JE',49.2079,-2.1955], GCI:['Guernsey','Guernsey','GG',49.4349,-2.6019],
    DUB:['Dublin','Dublin','IE',53.4213,-6.2701], ORK:['Cork','Cork','IE',51.8413,-8.4911], SNN:['Shannon','Shannon','IE',52.7020,-8.9248],
    CDG:['Paris','Paris Charles de Gaulle','FR',49.0097,2.5479], ORY:['Paris','Paris Orly','FR',48.7233,2.3794],
    BVA:['Paris','Paris Beauvais','FR',49.4544,2.1128], LIL:['Lille','Lille','FR',50.5619,3.0894],
    DNR:['Dinard/St-Malo','Dinard Bretagne','FR',48.5877,-2.0799], RNS:['Rennes','Rennes Bretagne','FR',48.0695,-1.7348],
    NTE:['Nantes','Nantes Atlantique','FR',47.1532,-1.6107], LYS:['Lyon','Lyon Saint-Exupéry','FR',45.7256,5.0811],
    NCE:['Nice','Nice Côte d’Azur','FR',43.6584,7.2159], MRS:['Marseille','Marseille Provence','FR',43.4393,5.2214],
    BOD:['Bordeaux','Bordeaux','FR',44.8283,-0.7156], TLS:['Toulouse','Toulouse Blagnac','FR',43.6293,1.3638],
    AMS:['Amsterdam','Amsterdam Schiphol','NL',52.3105,4.7683], RTM:['Rotterdam','Rotterdam The Hague','NL',51.9569,4.4372],
    EIN:['Eindhoven','Eindhoven','NL',51.4501,5.3747], BRU:['Brussels','Brussels','BE',50.9014,4.4844],
    CRL:['Charleroi','Brussels South Charleroi','BE',50.4592,4.4538], ANR:['Antwerp','Antwerp','BE',51.1894,4.4603],
    LUX:['Luxembourg','Luxembourg','LU',49.6233,6.2044],
    FRA:['Frankfurt','Frankfurt','DE',50.0379,8.5622], MUC:['Munich','Munich','DE',48.3538,11.7861], BER:['Berlin','Berlin Brandenburg','DE',52.3667,13.5033],
    HAM:['Hamburg','Hamburg','DE',53.6304,9.9882], DUS:['Düsseldorf','Düsseldorf','DE',51.2895,6.7668], CGN:['Cologne','Cologne Bonn','DE',50.8659,7.1427],
    STR:['Stuttgart','Stuttgart','DE',48.6899,9.2220], ZRH:['Zurich','Zurich','CH',47.4582,8.5555], GVA:['Geneva','Geneva','CH',46.2381,6.1089],
    VIE:['Vienna','Vienna','AT',48.1103,16.5697], PRG:['Prague','Václav Havel Prague','CZ',50.1008,14.2600],
    WAW:['Warsaw','Warsaw Chopin','PL',52.1657,20.9671], BUD:['Budapest','Budapest Ferenc Liszt','HU',47.4369,19.2556],
    CPH:['Copenhagen','Copenhagen','DK',55.6180,12.6508], OSL:['Oslo','Oslo Gardermoen','NO',60.1976,11.1004],
    ARN:['Stockholm','Stockholm Arlanda','SE',59.6519,17.9186], HEL:['Helsinki','Helsinki-Vantaa','FI',60.3172,24.9633],
    KEF:['Reykjavik','Keflavik','IS',63.9850,-22.6056], GOT:['Gothenburg','Gothenburg Landvetter','SE',57.6628,12.2798],
    MAD:['Madrid','Madrid Barajas','ES',40.4983,-3.5676], BCN:['Barcelona','Barcelona El Prat','ES',41.2974,2.0833],
    AGP:['Malaga','Malaga Costa del Sol','ES',36.6749,-4.4991], LIS:['Lisbon','Lisbon Humberto Delgado','PT',38.7742,-9.1342],
    OPO:['Porto','Porto','PT',41.2481,-8.6814], FCO:['Rome','Rome Fiumicino','IT',41.8003,12.2389], MXP:['Milan','Milan Malpensa','IT',45.6306,8.7281],
    VCE:['Venice','Venice Marco Polo','IT',45.5053,12.3519], ATH:['Athens','Athens Eleftherios Venizelos','GR',37.9364,23.9445],
    IST:['Istanbul','Istanbul Airport','TR',41.2753,28.7519], SAW:['Istanbul','Sabiha Gökçen','TR',40.8986,29.3092],
    ESB:['Ankara','Ankara Esenboğa','TR',40.1281,32.9951], ADB:['Izmir','Izmir Adnan Menderes','TR',38.2924,27.1570],
    AYT:['Antalya','Antalya','TR',36.8987,30.8005], KCO:['Kocaeli','Kocaeli Cengiz Topel','TR',40.7352,30.0833],
    BJV:['Bodrum','Milas-Bodrum','TR',37.2506,27.6643], TZX:['Trabzon','Trabzon','TR',40.9951,39.7897],
    DXB:['Dubai','Dubai International','AE',25.2532,55.3657], DOH:['Doha','Hamad International','QA',25.2731,51.6081],
    CAI:['Cairo','Cairo International','EG',30.1219,31.4056], CMN:['Casablanca','Mohammed V','MA',33.3675,-7.5899],
    JFK:['New York','New York JFK','US',40.6413,-73.7781], SFO:['San Francisco','San Francisco','US',37.6213,-122.3790],
    LAX:['Los Angeles','Los Angeles','US',33.9416,-118.4085], BOS:['Boston','Boston Logan','US',42.3656,-71.0096],
    YYZ:['Toronto','Toronto Pearson','CA',43.6777,-79.6248], NRT:['Tokyo','Tokyo Narita','JP',35.7720,140.3929],
    HND:['Tokyo','Tokyo Haneda','JP',35.5494,139.7798], SIN:['Singapore','Singapore Changi','SG',1.3644,103.9915],
    SYD:['Sydney','Sydney Kingsford Smith','AU',-33.9399,151.1753], GRU:['São Paulo','São Paulo Guarulhos','BR',-23.4356,-46.4731]
  };
  var R = Math.PI / 180;
  function ap(c) { var a = A[c]; return a ? { code: c, city: a[0], name: a[1], cc: a[2], lat: a[3], lon: a[4] } : null; }
  var FIXED = { 'LHR-CDG': 348, 'CDG-LHR': 348 }; // canonical demo values (brief persona): MR 0142 is 348 km / 42 min
  function gc(a, b) { // km
    if (FIXED[a + '-' + b]) return FIXED[a + '-' + b];
    var p = ap(a) || a, q = ap(b) || b;
    var dφ = (q.lat - p.lat) * R, dλ = (q.lon - p.lon) * R;
    var h = Math.sin(dφ / 2) * Math.sin(dφ / 2) + Math.cos(p.lat * R) * Math.cos(q.lat * R) * Math.sin(dλ / 2) * Math.sin(dλ / 2);
    return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
  }
  function minutes(km) { return Math.round(15 + km / 12.9); }
  function kmFor(min) { return Math.max(0, (min - 15) * 12.9); }
  function fmtDur(m) { m = Math.round(m); if (m < 60) return m + ' min'; var h = Math.floor(m / 60), r = m % 60; return r ? h + 'h ' + r + 'm' : h + 'h'; }
  function fmtShort(m) { m = Math.round(m); if (m < 60) return m + 'm'; var h = Math.floor(m / 60), r = m % 60; return r ? h + 'h ' + r + 'm' : h + 'h'; }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function mmss(sec) { sec = Math.max(0, Math.round(sec)); return pad(Math.floor(sec / 60)) + ':' + pad(sec % 60); }
  function hms(sec) { sec = Math.max(0, Math.round(sec)); var h = Math.floor(sec / 3600); return (h ? h + ':' : '') + pad(Math.floor(sec % 3600 / 60)) + ':' + pad(sec % 60); }
  function rng(seed) { var a = seed >>> 0; return function () { a |= 0; a = a + 0x6D2B79F5 | 0; var t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  function hash(s) { var h = 2166136261; s = String(s); for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  // projections
  var EU = { lon0: -35, lon1: 60, lat0: 22, lat1: 70, W: 3200, H: 2589, k: 1929.963099388036 };
  function my(lat) { return Math.log(Math.tan(Math.PI / 4 + lat * R / 2)); }
  EU.xy = function (lat, lon) { return [EU.k * (lon - EU.lon0) * R, EU.k * (my(EU.lat1) - my(lat))]; };
  EU.kmPerPx = function (lat) { return 40075 * Math.cos(lat * R) / (EU.k * 2 * Math.PI); };
  var EQ = { W: 1440, H: 720, xy: function (lat, lon) { return [(lon + 180) / 360 * 1440, (90 - lat) / 180 * 720]; } };
  function arc(p, q, n) { // great-circle points [lat,lon]
    p = ap(p) || p; q = ap(q) || q; n = n || 48;
    var φ1 = p.lat * R, λ1 = p.lon * R, φ2 = q.lat * R, λ2 = q.lon * R;
    var d = 2 * Math.asin(Math.sqrt(Math.pow(Math.sin((φ2 - φ1) / 2), 2) + Math.cos(φ1) * Math.cos(φ2) * Math.pow(Math.sin((λ2 - λ1) / 2), 2)));
    var pts = [];
    if (d < 1e-6) return [[p.lat, p.lon]];
    for (var i = 0; i <= n; i++) {
      var f = i / n, A1 = Math.sin((1 - f) * d) / Math.sin(d), B1 = Math.sin(f * d) / Math.sin(d);
      var x = A1 * Math.cos(φ1) * Math.cos(λ1) + B1 * Math.cos(φ2) * Math.cos(λ2);
      var y = A1 * Math.cos(φ1) * Math.sin(λ1) + B1 * Math.cos(φ2) * Math.sin(λ2);
      var z = A1 * Math.sin(φ1) + B1 * Math.sin(φ2);
      pts.push([Math.atan2(z, Math.sqrt(x * x + y * y)) / R, Math.atan2(y, x) / R]);
    }
    return pts;
  }
  function pathFrom(pts, proj, lift) { // svg path through projected points; lift raises the middle (visual arc) in px
    var d = '', prevX = null;
    for (var i = 0; i < pts.length; i++) {
      var xy = proj(pts[i][0], pts[i][1]), x = xy[0], y = xy[1];
      if (lift) { var f = i / (pts.length - 1); y -= Math.sin(f * Math.PI) * lift; }
      if (prevX !== null && Math.abs(x - prevX) > 600) d += 'M'; else d += i ? 'L' : 'M';
      d += x.toFixed(1) + ' ' + y.toFixed(1) + ' ';
      prevX = x;
    }
    return d;
  }
  // torn edge: polygon px string for a w×h box whose bottom edge is jagged around y=h
  function tornPolygon(w, h, seed, amp, step) {
    amp = amp || 2; step = step || 4;
    var r = rng(seed), pts = ['0px 0px', w + 'px 0px'], x = w, y;
    while (x > 0) { y = h - amp + r() * amp * 1.0; pts.push(x.toFixed(1) + 'px ' + (y).toFixed(2) + 'px'); x -= step * (0.6 + r() * 0.8); }
    pts.push('0px ' + (h - amp * 0.5).toFixed(2) + 'px');
    return 'polygon(' + pts.join(',') + ')';
  }
  // PDF417-like stacked bar rows; returns a single svg path d for a w×h area
  function barcodePath(seed, w, h, rows) {
    rows = rows || 6; var r = rng(seed), rh = h / rows, d = '';
    for (var row = 0; row < rows; row++) {
      var x = 0, y = row * rh, on = true;
      // start pattern
      var st = [3, 1, 1, 1, 1, 1, 1, 3];
      var unit = w / 150;
      for (var i = 0; i < st.length; i++) { if (i % 2 === 0) d += 'M' + (x).toFixed(2) + ' ' + y.toFixed(2) + 'h' + (st[i] * unit).toFixed(2) + 'v' + (rh - 0.6).toFixed(2) + 'h-' + (st[i] * unit).toFixed(2) + 'z'; x += st[i] * unit; }
      while (x < w - 9 * unit) {
        var wd = (1 + Math.floor(r() * 4)) * unit * (0.9 + r() * 0.3);
        if (on) d += 'M' + x.toFixed(2) + ' ' + y.toFixed(2) + 'h' + wd.toFixed(2) + 'v' + (rh - 0.6).toFixed(2) + 'h-' + wd.toFixed(2) + 'z';
        x += wd; on = !on;
      }
      var sp = [7, 1, 1, 1, 1, 1, 2, 1];
      x = w - 17 * unit;
      for (var j = 0; j < sp.length; j++) { if (j % 2 === 0) d += 'M' + (x).toFixed(2) + ' ' + y.toFixed(2) + 'h' + (Math.min(sp[j], 3) * unit).toFixed(2) + 'v' + (rh - 0.6).toFixed(2) + 'h-' + (Math.min(sp[j], 3) * unit).toFixed(2) + 'z'; x += sp[j] * unit * 0.7; }
    }
    return d;
  }
  // ticket route watermark: world-dot mask position so both airports sit inside a box
  function worldFit(a, b, bw, bh) {
    var p = ap(a), q = ap(b), P = EQ.xy(p.lat, p.lon), Q = EQ.xy(q.lat, q.lon);
    var dx = Math.abs(P[0] - Q[0]) / 1440, dy = Math.abs(P[1] - Q[1]) / 720;
    var s = Math.min(bw * 0.7 / Math.max(dx, 0.002), bh * 1.6 / Math.max(dy, 0.002)); // world width px
    s = Math.max(bw * 1.1, Math.min(s, 6000));
    var mx = (P[0] + Q[0]) / 2 / 1440 * s, my_ = (P[1] + Q[1]) / 2 / 720 * (s / 2);
    var ox = bw / 2 - mx, oy = bh / 2 - my_;
    return { s: s, ox: ox, oy: oy, p: [P[0] / 1440 * s + ox, P[1] / 720 * (s / 2) + oy], q: [Q[0] / 1440 * s + ox, Q[1] / 720 * (s / 2) + oy] };
  }
  var CN = { GB:'United Kingdom', FR:'France', NL:'Netherlands', BE:'Belgium', DE:'Germany', IE:'Ireland', ES:'Spain', PT:'Portugal', IT:'Italy', CH:'Switzerland', AT:'Austria', DK:'Denmark', NO:'Norway', SE:'Sweden', FI:'Finland', IS:'Iceland', PL:'Poland', CZ:'Czechia', HU:'Hungary', GR:'Greece', TR:'Türkiye', LU:'Luxembourg', JE:'Jersey', GG:'Guernsey', AE:'UAE', QA:'Qatar', EG:'Egypt', MA:'Morocco', US:'United States', CA:'Canada', JP:'Japan', SG:'Singapore', AU:'Australia', BR:'Brazil' };
  var FL = { GB:['h','#1D2F6F','#F4F4F4','#C8202F'], FR:['v','#1F3C88','#F4F4F4','#E1252B'], NL:['h','#AE1C28','#F4F4F4','#21468B'], DE:['h','#15171C','#D00000','#FFCE00'], ES:['h','#C60B1E','#FFC400','#C60B1E'], IT:['v','#009246','#F4F4F4','#CE2B37'], BE:['v','#15171C','#FAE042','#ED2939'], IE:['v','#169B62','#F4F4F4','#FF883E'], CH:['s','#D52B1E'], TR:['s','#E30A17'], AT:['h','#ED2939','#F4F4F4','#ED2939'], DK:['s','#C8102E'], NO:['s','#BA0C2F'], SE:['s','#006AA7'], FI:['s','#F4F4F4'], IS:['s','#02529C'], PL:['h','#F4F4F4','#F4F4F4','#DC143C'], CZ:['h','#F4F4F4','#F4F4F4','#D7141A'], HU:['h','#CE2939','#F4F4F4','#477050'], GR:['s','#0D5EAF'], PT:['v','#046A38','#046A38','#DA291C'], LU:['h','#ED2939','#F4F4F4','#00A3E0'], JP:['s','#F4F4F4'], US:['h','#B22234','#F4F4F4','#3C3B6E'], AE:['v','#00732F','#F4F4F4','#15171C'], QA:['s','#8A1538'], EG:['h','#CE1126','#F4F4F4','#15171C'], MA:['s','#C1272D'], SG:['h','#EF3340','#EF3340','#F4F4F4'], CA:['v','#D52B1E','#F4F4F4','#D52B1E'], AU:['s','#00247D'], BR:['s','#009C3B'], JE:['s','#F4F4F4'], GG:['s','#F4F4F4'] };
  function flagBg(cc) { var f = FL[cc]; if (!f) return '#6B7592'; if (f[0] === 's') return f[1]; var d = f[0] === 'h' ? '180deg' : '90deg'; return 'linear-gradient(' + d + ',' + f[1] + ' 0 33.4%,' + f[2] + ' 33.4% 66.6%,' + f[3] + ' 66.6%)'; }
  var CONT = { GB:'eu',JE:'eu',GG:'eu',IE:'eu',FR:'eu',NL:'eu',BE:'eu',LU:'eu',DE:'eu',CH:'eu',AT:'eu',CZ:'eu',PL:'eu',HU:'eu',DK:'eu',NO:'eu',SE:'eu',FI:'eu',IS:'eu',ES:'eu',PT:'eu',IT:'eu',GR:'eu',TR:'eu',AE:'as',QA:'as',JP:'as',SG:'as',EG:'af',MA:'af',US:'na',CA:'na',BR:'sa',AU:'oc' };
  function continent(code) { var a = A[code]; return a ? (CONT[a[2]] || 'eu') : 'eu'; }
  var SC = { study: ['Study', '#7AA2FF', 'cap'], work: ['Work', '#FFB86B', 'case'], read: ['Read', '#7ADDB2', 'book'], create: ['Create', '#FF8FB1', 'spark'], code: ['Coding', '#B49CFF', 'code'], meditate: ['Meditate', '#8EE3E8', 'lotus'], fitness: ['Fitness', '#FF9B7A', 'dumbbell'], other: ['Other', '#C7CCDA', 'dot'] };
  function cabin(min) { return min < 45 ? 'economy' : min < 90 ? 'premium' : min < 180 ? 'business' : min < 300 ? 'first' : 'long'; }
  var CABIN = { economy: 'Economy', premium: 'Premium', business: 'Business', first: 'First', long: 'Long-haul' };
  var TIERS = [
    { k: 'departure', name: 'Departure', km: 0, tag: 'Every route begins somewhere.' },
    { k: 'cruise', name: 'Cruise', km: 1000, tag: 'Altitude is a kind of calm.' },
    { k: 'jetstream', name: 'Jetstream', km: 5000, tag: 'Carried by the current.' },
    { k: 'gold', name: 'Meridian Gold', km: 20000, tag: 'The line everything is measured from.' },
    { k: 'equator', name: 'Equator', km: 40075, tag: 'Once around the world.' },
    { k: 'obsidian', name: 'Obsidian', km: 100000, tag: 'Beyond the horizon line.' }
  ];
  var ME = { name: 'Elif Kaya', first: 'Elif', km: 12022, flights: 87, hours: 94.5, countries: 19, airports: 41, streak: 12, since: 'Mar 2025', member: '0048 1317 2204', home: 'LHR' };
  function fmtKm(n) { return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
  window.MeridianKit = { countries: CN, flagBg: flagBg, tiers: TIERS, me: ME, fmtKm: fmtKm, continent: continent, airports: A, ap: ap, gc: gc, minutes: minutes, kmFor: kmFor, fmtDur: fmtDur, fmtShort: fmtShort, mmss: mmss, hms: hms, pad: pad, rng: rng, hash: hash, eu: EU, eq: EQ, arc: arc, pathFrom: pathFrom, tornPolygon: tornPolygon, barcodePath: barcodePath, worldFit: worldFit, scenarios: SC, cabin: cabin, cabinName: CABIN };
})();

;(function () {
  // Aircraft top-view geometry (nose up, 100 x 100 box, centre line x = 50). Shared by Plane, SeatMap, Takeoff, WindowView, icons.
  var SPEC = {
    twin: { fw: 4.8, n: 3, t: 97.6, w: { rx: 54.4, rle: 39.5, rte: 57.4, tx: 96.4, tle: 59.6, tte: 64.8, kx: 68.5, kte: 58.9 }, e: { x: 67.4, w: 5.8, y0: 37.2, y1: 54.6 }, s: { rle: 83.6, rte: 91.8, tx: 68.6, tle: 92.2, tte: 95.4 }, f: { y0: 78, y1: 96.8, w: 1.8 }, lets: true },
    wide: { fw: 5.7, n: 2, t: 98, w: { rx: 55.4, rle: 33.8, rte: 60.4, tx: 97.8, tle: 60.6, tte: 67.6, kx: 73, kte: 62.6 }, e: { x: 70.2, w: 7.6, y0: 33.2, y1: 57.2 }, s: { rle: 81.8, rte: 92.6, tx: 75, tle: 93.4, tte: 96.9 }, f: { y0: 76, y1: 97.4, w: 2.1 }, lets: true },
    prop: { fw: 3.7, n: 4, t: 97, w: { rx: 53.5, rle: 37, rte: 48.4, tx: 95.2, tle: 39, tte: 48.6, kx: 53.5, kte: 48.4 }, e: { x: 68.2, w: 4.6, y0: 27, y1: 47.6, prop: true }, s: { rle: 86.4, rte: 92.4, tx: 67.6, tle: 88.4, tte: 93.6 }, f: { y0: 82, y1: 96.2, w: 1.6 }, lets: false }
  };
  function f1(v) { return (Math.round(v * 100) / 100).toString(); }
  function plane(variant) {
    var c = SPEC[variant] || SPEC.twin, w = c.w, e = c.e, st = c.s, fw = c.fw, n = c.n, t = c.t;
    function X(s, x) { return 50 + s * (x - 50); }
    var fus = 'M50 ' + n + ' C' + f1(50 + fw * .72) + ' ' + n + ' ' + f1(50 + fw) + ' ' + f1(n + 5.2) + ' ' + f1(50 + fw) + ' ' + f1(n + 14.5) + ' L' + f1(50 + fw) + ' ' + f1(t - 31) + ' C' + f1(50 + fw) + ' ' + f1(t - 19) + ' ' + f1(50 + fw * .3) + ' ' + f1(t - 5) + ' ' + f1(50 + fw * .2) + ' ' + t + ' L' + f1(50 - fw * .2) + ' ' + t + ' C' + f1(50 - fw * .3) + ' ' + f1(t - 5) + ' ' + f1(50 - fw) + ' ' + f1(t - 19) + ' ' + f1(50 - fw) + ' ' + f1(t - 31) + ' L' + f1(50 - fw) + ' ' + f1(n + 14.5) + ' C' + f1(50 - fw) + ' ' + f1(n + 5.2) + ' ' + f1(50 - fw * .72) + ' ' + n + ' 50 ' + n + 'Z';
    function wingPath(s) { var m = (w.tle + w.tte) / 2; return 'M' + f1(X(s, w.rx - .6)) + ' ' + w.rle + ' L' + f1(X(s, w.tx)) + ' ' + w.tle + ' Q' + f1(X(s, w.tx + .9)) + ' ' + f1(m) + ' ' + f1(X(s, w.tx - .1)) + ' ' + w.tte + ' L' + f1(X(s, w.kx)) + ' ' + w.kte + ' L' + f1(X(s, w.rx - .6)) + ' ' + w.rte + 'Z'; }
    function stabPath(s) { var m = (st.tle + st.tte) / 2; return 'M' + f1(X(s, 50 + fw - .6)) + ' ' + st.rle + ' L' + f1(X(s, st.tx)) + ' ' + st.tle + ' Q' + f1(X(s, st.tx + .6)) + ' ' + f1(m) + ' ' + f1(X(s, st.tx - .1)) + ' ' + st.tte + ' L' + f1(X(s, 50 + fw - .6)) + ' ' + st.rte + 'Z'; }
    function nac(s) { var cx = X(s, e.x), hw = e.w / 2; return 'M' + f1(cx - hw) + ' ' + f1(e.y0 + 2) + ' Q' + f1(cx - hw) + ' ' + e.y0 + ' ' + f1(cx) + ' ' + e.y0 + ' Q' + f1(cx + hw) + ' ' + e.y0 + ' ' + f1(cx + hw) + ' ' + f1(e.y0 + 2) + ' L' + f1(cx + hw) + ' ' + f1(e.y1 - 2.4) + ' Q' + f1(cx + hw) + ' ' + f1(e.y1) + ' ' + f1(cx + hw * .5) + ' ' + f1(e.y1 + .5) + ' L' + f1(cx - hw * .5) + ' ' + f1(e.y1 + .5) + ' Q' + f1(cx - hw) + ' ' + f1(e.y1) + ' ' + f1(cx - hw) + ' ' + f1(e.y1 - 2.4) + 'Z'; }
    function ell(cx, cy, rx, ry) { return 'M' + f1(cx - rx) + ' ' + f1(cy) + ' A' + f1(rx) + ' ' + f1(ry) + ' 0 1 0 ' + f1(cx + rx) + ' ' + f1(cy) + ' A' + f1(rx) + ' ' + f1(ry) + ' 0 1 0 ' + f1(cx - rx) + ' ' + f1(cy) + 'Z'; }
    function leAt(x) { return w.rle + (x - w.rx) / (w.tx - w.rx) * (w.tle - w.rle); }
    function teAt(x) { return x <= w.kx ? w.rte + (x - w.rx) / (w.kx - w.rx || 1) * (w.kte - w.rte) : w.kte + (x - w.kx) / (w.tx - w.kx) * (w.tte - w.kte); }
    function at(x, fr) { var a = leAt(x), b = teAt(x); return a + (b - a) * fr; }
    // panel lines (flaps, ailerons, slats, spoilers)
    var L = [], s, xs;
    function seg(x1, f1_, x2, f2) { return [x1, at(x1, f1_), x2, at(x2, f2)]; }
    var xr = w.rx + 1.2, xk = w.kx, xt = w.tx - 1.4;
    L.push(seg(xr, .74, xk - 1, .76)); L.push(seg(xk + 2, .8, xt - 2.6, .82)); L.push(seg(xk + 2, .66, xt - 2.6, .68));
    L.push(seg(xr, .14, xk, .13)); L.push(seg(xk, .12, xt, .1));
    L.push(seg(xk - 6, .3, xk - 6, .76)); L.push(seg(xk + 7, .66, xk + 7, .8)); L.push(seg(xk + 15, .64, xk + 15, .82));
    var lines = ''; for (s = 1; s >= -1; s -= 2) L.forEach(function (q) { lines += 'M' + f1(X(s, q[0])) + ' ' + f1(q[1]) + ' L' + f1(X(s, q[2])) + ' ' + f1(q[3]) + ' '; });
    var fa = 50 + fw - .4;
    var fair = 'M' + f1(50 + fw - .2) + ' ' + f1(w.rle + 1.2) + ' Q' + f1(50 + fw + 3.1) + ' ' + f1((w.rle + w.rte) / 2 + 2) + ' ' + f1(50 + fw - .2) + ' ' + f1(w.rte + 5.5) + ' L' + f1(50 - fw + .2) + ' ' + f1(w.rte + 5.5) + ' Q' + f1(50 - fw - 3.1) + ' ' + f1((w.rle + w.rte) / 2 + 2) + ' ' + f1(50 - fw + .2) + ' ' + f1(w.rle + 1.2) + 'Z';
    var winglet = '', s2;
    if (c.lets) for (s2 = 1; s2 >= -1; s2 -= 2) winglet += 'M' + f1(X(s2, w.tx - .5)) + ' ' + f1(w.tle + 1.2) + ' L' + f1(X(s2, w.tx + 1.1)) + ' ' + f1(w.tle - 3.2) + ' L' + f1(X(s2, w.tx + 1.5)) + ' ' + f1(w.tle - 2.8) + ' L' + f1(X(s2, w.tx + .9)) + ' ' + f1(w.tle + 3.8) + 'Z ';
    var win = 'M' + f1(50 - fw * .6) + ' ' + f1(n + 6.9) + ' L' + f1(50 - fw * .4) + ' ' + f1(n + 4.7) + ' Q50 ' + f1(n + 4.1) + ' ' + f1(50 + fw * .4) + ' ' + f1(n + 4.7) + ' L' + f1(50 + fw * .6) + ' ' + f1(n + 6.9) + ' Q50 ' + f1(n + 6.1) + ' ' + f1(50 - fw * .6) + ' ' + f1(n + 6.9) + 'Z';
    var winRows = ''; var yy; for (yy = n + 14; yy < t - 26; yy += 2.9) { winRows += 'M' + f1(50 - fw + .25) + ' ' + f1(yy) + ' l0 .9 M' + f1(50 + fw - .25) + ' ' + f1(yy) + ' l0 .9 '; }
    return {
      v: variant, fus: fus, win: win, winRows: winRows, wings: wingPath(1) + ' ' + wingPath(-1), wingR: wingPath(1), wingL: wingPath(-1), stabs: stabPath(1) + ' ' + stabPath(-1), fair: fair, lines: lines, winglet: winglet,
      nacR: nac(1), nacL: nac(-1), eng: e, engC: [X(1, e.x), X(-1, e.x)],
      intakes: ell(X(1, e.x), e.y0 + .7, e.w * .38, .95) + ' ' + ell(X(-1, e.x), e.y0 + .7, e.w * .38, .95),
      exhaust: ell(X(1, e.x), e.y1 + .4, e.w * .2, .6) + ' ' + ell(X(-1, e.x), e.y1 + .4, e.w * .2, .6),
      fin: { x: 50 - c.f.w / 2, y: c.f.y0, w: c.f.w, h: c.f.y1 - c.f.y0 }, tips: { rx: w.tx, ry: (w.tle + w.tte) / 2, lx: 100 - w.tx, ty: t },
      fw: fw, nose: n, tail: t, wing: w, stab: st, at: at, leAt: leAt, teAt: teAt, prop: !!e.prop, lets: !!c.lets,
      yTop: w.rle, yBot: w.tte
    };
  }
  window.MeridianKit.plane = plane;
})();

;(function(){ if (!window.MeridianWorld && document.readyState === "loading") { document.write('<script src="./meridian-world.js"><\/script>'); } })();
