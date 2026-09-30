#!/usr/bin/env bash
# Runs the tests on this Mac. `swift test` cannot be used here: with swift.org 6.4.0 (swiftly) and
# the macOS 27 SDK on macOS 26, the test bundle needs the toolchain's own libswiftCore ahead of the
# system one, and `swift test` launches the testing helper with a clean environment.
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLCHAIN="${SWIFT_TOOLCHAIN:-6.4.0}"
swiftly run swift build "+${TOOLCHAIN}" --build-system native --scratch-path .build-native --build-tests
ROOT="$(dirname "$(dirname "$(swiftly run which swift "+${TOOLCHAIN}")")")"
export DYLD_LIBRARY_PATH="$ROOT/lib/swift/macosx:$ROOT/lib/swift/macosx/testing"
exec "$ROOT/libexec/swift/pm/swiftpm-testing-helper" \
    --test-bundle-path .build-native/arm64-apple-macosx/debug/PoEHatKitPackageTests.xctest/Contents/MacOS/PoEHatKitPackageTests \
    --testing-library swift-testing
