#!/bin/bash
# Runs the sound-engine unit tests without an Xcode test target: builds a throwaway SwiftPM package whose sources are
# symlinks to App/Meridian/Features/Audio and App/MeridianTests/Audio (same MainActor default isolation as the app).
# Offline rendering only, no audio device needed.   Usage: Scripts/audio-test.sh [swift test args]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${AUDIO_TEST_DIR:-${TMPDIR:-/tmp}/meridian-audio-test}"
rm -rf "$PKG"; mkdir -p "$PKG/Sources" "$PKG/Tests"
ln -s "$ROOT/App/Meridian/Features/Audio" "$PKG/Sources/MRAudio"
ln -s "$ROOT/App/MeridianTests/Audio" "$PKG/Tests/MRAudioTests"
cat > "$PKG/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let s: [SwiftSetting] = [.defaultIsolation(MainActor.self)]
let package = Package(
    name: "MRAudioTest",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MRAudio", path: "Sources/MRAudio", swiftSettings: s),
        .testTarget(name: "MRAudioTests", dependencies: ["MRAudio"], path: "Tests/MRAudioTests"),
    ]
)
SWIFT
cd "$PKG" && swift test "$@"
