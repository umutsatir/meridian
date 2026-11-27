#!/bin/bash
# Like app-shot.sh, with a pointer script and mid-run snapshots (Debug/CardSim.swift):
#   Scripts/sim-shot.sh <route> <out-dir> "<sim script>" [--delay 4] [other harness flags]
# Every `snap <name>` in the script lands in <out-dir>/<name>.png, the final frame in <out-dir>/final.png.
set -euo pipefail
ROUTE="$1"; OUT="$2"; SIM="$3"; shift 3
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${DERIVED:-$ROOT/.build-app}/Build/Products/Debug/Meridian.app"
TMP="$HOME/Library/Containers/app.meridian.Meridian/Data/tmp"
mkdir -p "$OUT"; LOG="$(mktemp)"
NAME="sim-$$-final.png"
open -n -W --stderr "$LOG" "$APP" --args --screen "$ROUTE" --screenshot "$NAME" --sim "$SIM" "$@"
cat "$LOG" >&2
for n in $(grep -o '^snap: .*' "$LOG" | cut -d' ' -f2); do mv "$TMP/$n.png" "$OUT/$n.png"; done
[ -s "$TMP/$NAME" ] && mv "$TMP/$NAME" "$OUT/final.png"
rm -f "$LOG"
