#!/bin/bash
# Render one canvas artboard from docs/design/export/project to a PNG (headless Brave).
#
#   Scripts/design-ref.sh <Artboard> <WxH|auto> <out.png> [budget_ms]
#
#   Artboard   file name without ".dc.html", e.g. S10B-Plan-Choose
#   WxH        window size in CSS px, e.g. 1280x800. "auto" reads the artboard's own
#              $preview size from its wrapper file (most S-screens are 1280x800).
#   budget_ms  --virtual-time-budget (default 8000). Raise it (12000-20000) for
#              animated or slowly loading artboards (maps, satellite, split-flap).
#
# Env: BRAVE=/path/to/binary  override the browser (any Chromium works).
#      TIMEOUT=90             seconds before the browser is killed.
#      SCALE=1               device scale factor (default 1: output is exactly WxH pixels).
set -euo pipefail

if [ $# -lt 3 ]; then sed -n '2,15p' "$0"; exit 2; fi
NAME="$1"; SIZE="$2"; OUT="$3"; BUDGET="${4:-8000}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/docs/design/export/project"
BRAVE="${BRAVE:-/Applications/Brave Browser.app/Contents/MacOS/Brave Browser}"
FILE="$SRC/$NAME.dc.html"

[ -f "$FILE" ] || { echo "no such artboard: $NAME ($FILE)" >&2; exit 1; }
[ -x "$BRAVE" ] || { echo "browser not found: $BRAVE" >&2; exit 1; }

if [ "$SIZE" = "auto" ]; then
  W=$(grep -o '"width":[0-9]*' "$FILE" | head -1 | cut -d: -f2)
  H=$(grep -o '"height":[0-9]*' "$FILE" | head -1 | cut -d: -f2)
  [ -n "$W" ] && [ -n "$H" ] || { echo "no \$preview size in $NAME, pass WxH" >&2; exit 1; }
else
  W="${SIZE%x*}"; H="${SIZE#*x}"
fi

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
PROFILE="$(mktemp -d)"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SRC" >/dev/null 2>&1 &
SERVER=$!
cleanup() { kill "$SERVER" 2>/dev/null || true; wait "$SERVER" 2>/dev/null || true; rm -rf "$PROFILE"; }
trap cleanup EXIT

# wait for the server
for _ in $(seq 1 50); do
  curl -sf -o /dev/null "http://127.0.0.1:$PORT/$NAME.dc.html" && break
  sleep 0.1
done

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
"$BRAVE" --headless=new --disable-gpu --hide-scrollbars \
  ${USE_PROFILE:+--user-data-dir="$PROFILE"} \
  --force-device-scale-factor="${SCALE:-1}" \
  --window-size="$W,$H" --virtual-time-budget="$BUDGET" \
  --screenshot="$OUT" "http://127.0.0.1:$PORT/$NAME.dc.html" >"${BROWSER_LOG:-/dev/null}" 2>&1 &
BROWSER=$!
# watchdog: headless Brave sometimes keeps running after the PNG is written
LIMIT="${TIMEOUT:-90}"
for _ in $(seq 1 $((LIMIT * 5))); do
  kill -0 "$BROWSER" 2>/dev/null || break
  [ -s "$OUT" ] && { sleep 1; break; }
  sleep 0.2
done
kill "$BROWSER" 2>/dev/null || true
wait "$BROWSER" 2>/dev/null || true

if [ ! -s "$OUT" ]; then echo "screenshot failed for $NAME" >&2; exit 1; fi
echo "$OUT ($W x $H, budget ${BUDGET}ms)"
