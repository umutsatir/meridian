#!/bin/bash
# Render one app screen to a 1x PNG with the in-app screenshot harness (App/Meridian/Debug).
#
#   Scripts/app-shot.sh <route> <out.png> [--size 1280x800] [--delay 1.5] [--theme dark|light] [--capture window|cache]
#
# Env: DERIVED=<derived-data dir>  (default: .build-app in the repo; built if missing)
#      NOBUILD=1                   skip xcodebuild
#
# The app is sandboxed, so it writes the PNG into its container
# (~/Library/Containers/app.meridian.Meridian/Data/tmp) and this script copies it to <out.png>.
# It is launched through LaunchServices (`open -n -W`): running the binary directly from a
# non-GUI shell never creates the window. No screen-recording permission is involved.
set -euo pipefail

if [ $# -lt 2 ]; then sed -n '2,12p' "$0"; exit 2; fi
ROUTE="$1"; OUT="$2"; shift 2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED:-$ROOT/.build-app}"
APP="$DERIVED/Build/Products/Debug/Meridian.app"

if [ -z "${NOBUILD:-}" ]; then
  xcodebuild -project "$ROOT/App/Meridian.xcodeproj" -scheme Meridian -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" build -quiet >/dev/null
fi
[ -d "$APP" ] || { echo "app not built: $APP" >&2; exit 1; }

NAME="shot-$$-$(basename "$OUT")"
CONTAINER_TMP="$HOME/Library/Containers/app.meridian.Meridian/Data/tmp"
LOG="$(mktemp)"
rm -f "$CONTAINER_TMP/$NAME" "$OUT"
open -n -W --stderr "$LOG" "$APP" --args --screen "$ROUTE" --screenshot "$NAME" "$@"
cat "$LOG" >&2   # prints: content=WxH window=WxH (both must equal --size)
if [ ! -s "$CONTAINER_TMP/$NAME" ]; then echo "no screenshot produced" >&2; rm -f "$LOG"; exit 1; fi
mkdir -p "$(dirname "$OUT")"
mv "$CONTAINER_TMP/$NAME" "$OUT"
rm -f "$LOG"
echo "$OUT"
