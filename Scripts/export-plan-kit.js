// Exports the canvas kit data used by the Plan screens (airports in canvas order, countries, flag stripes)
// to App/Meridian/Features/Plan/Resources/plan-kit.json. Run: node Scripts/export-plan-kit.js
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'docs/design/export/project/meridian-kit.js'), 'utf8');
global.window = {}; global.document = { readyState: 'complete' };
new Function('window', src)(global.window);
const K = global.window.MeridianKit;
const flagsSrc = src.match(/var FL = (\{.*?\});/s)[1];
const FL = new Function('return ' + flagsSrc)();
const out = {
  airports: Object.keys(K.airports).map(c => { const a = K.airports[c]; return { iata: c, city: a[0], name: a[1], cc: a[2], lat: a[3], lon: a[4] }; }),
  countries: K.countries,
  flags: FL,
  scenarios: K.scenarios,
};
fs.writeFileSync(path.join(root, 'App/Meridian/Features/Plan/Resources/plan-kit.json'), JSON.stringify(out));
console.log(out.airports.length, 'airports');
