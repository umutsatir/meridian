#!/bin/bash
# Runs App/MeridianTests/Cards/CoverflowHitTestTests.swift (the app project has no test target) in a throw-away SwiftPM
# package that symlinks the two pure source files it needs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/Sources/Geo" "$TMP/Tests/GeoTests"
ln -s "$ROOT/App/Meridian/Features/Cards/CSS3D.swift" "$TMP/Sources/Geo/CSS3D.swift"
ln -s "$ROOT/App/Meridian/Features/Cards/CoverflowGeometry.swift" "$TMP/Sources/Geo/CoverflowGeometry.swift"
sed 's/@testable import Meridian/@testable import Geo/' "$ROOT/App/MeridianTests/Cards/CoverflowHitTestTests.swift" > "$TMP/Tests/GeoTests/T.swift"
cat > "$TMP/Package.swift" <<'EOF'
// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "Geo", platforms: [.macOS(.v14)],
  targets: [.target(name: "Geo"), .testTarget(name: "GeoTests", dependencies: ["Geo"])])
EOF
cd "$TMP" && swift test 2>&1 | tail -25
