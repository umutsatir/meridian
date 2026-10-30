#!/bin/zsh
# Rasterizes the design's terrain-fields.svg (blurred polygons + feTurbulence noise, which Canvas cannot draw)
# into the 2000x2000 JPEG texture MeridianMaps tiles for the Satellite style. The CSS of the canvas applies
# `filter: saturate(.8) brightness(.9)` to it; that filter is baked in here so the app draws the texture plainly.
#
# Usage: Scripts/maps/rasterize-terrain.sh <design/project dir> [out.png]
# Needs Brave (or Chrome) and python3.
set -e
SRC=${1:?design project dir}
OUT=${2:-"$(cd "$(dirname "$0")/../.." && pwd)/Packages/MeridianMaps/Sources/MeridianMaps/Resources/terrain-fields.jpg"}
BROWSER=${BROWSER:-"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"}
TMP=$(mktemp -d)
cp "$SRC/terrain-fields.svg" "$TMP/"
cat > "$TMP/t.html" <<EOF
<!doctype html><body style="margin:0;background:#000"><img src="terrain-fields.svg" width="2000" height="2000" style="display:block;filter:saturate(.8) brightness(.9)"></body>
EOF
cd "$TMP"
python3 -m http.server 8793 >/dev/null 2>&1 &
PID=$!
sleep 1
"$BROWSER" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=2000,2000 \
  --virtual-time-budget=8000 --screenshot="$TMP/t.png" http://localhost:8793/t.html
kill $PID
sips -s format jpeg -s formatOptions 90 "$TMP/t.png" --out "$OUT" >/dev/null
echo "wrote $OUT"
