#!/usr/bin/env python3
"""Builds MeridianMaps' bundled data files from the design canvas working copy.

Usage: Scripts/maps/build-map-data.py <design/project dir> [resources dir]

Reads   meridian-world.js, meridian-kit.js, map-europe-land.svg, map-europe-borders.svg
Writes  world.json            (land/borders/hi/mid/lo rings, flat [lon*10, lat*10, ...] like the JS)
        design-airports.json  (K.airports of the design: code -> [city, name, cc, lat, lon])
        map-europe-land.svg, map-europe-borders.svg (copied verbatim, parsed at runtime by SVGPathParser)

The output is committed; the package build does not depend on this script.
Terrain texture: see Scripts/maps/rasterize-terrain.sh.
"""
import json
import re
import shutil
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parents[2] / "Packages/MeridianMaps/Sources/MeridianMaps/Resources"
out.mkdir(parents=True, exist_ok=True)

# world geometry: `window.MeridianWorld={...};` followed by the projection helpers
js = (src / "meridian-world.js").read_text()
start = js.index("window.MeridianWorld=") + len("window.MeridianWorld=")
end = js.index(";\n(function", start)
world = json.loads(js[start:end])
assert set(world) == {"land", "borders", "hi", "mid", "lo"}, world.keys()
(out / "world.json").write_text(json.dumps(world, separators=(",", ":")))

# airports of the design kit
kit = (src / "meridian-kit.js").read_text()
m = re.search(r"var A = \{(.*?)\n  \};", kit, re.S)
assert m, "airport table not found"
airports = {}
for code, city, name, cc, lat, lon in re.findall(
        r"([A-Z]{3}):\['([^']*)','([^']*)','([A-Z]{2})',(-?[\d.]+),(-?[\d.]+)\]", m.group(1)):
    airports[code] = [city, name, cc, float(lat), float(lon)]
(out / "design-airports.json").write_text(json.dumps(airports, ensure_ascii=False, separators=(",", ":")))

for name in ("map-europe-land.svg", "map-europe-borders.svg"):
    shutil.copy(src / name, out / name)

print({k: len(v) for k, v in world.items()}, len(airports), "airports ->", out)
