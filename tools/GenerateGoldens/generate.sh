#!/bin/sh
# Regenerate Tests/SwiftTiffTests/Goldens from the ObjC reference implementation.
#
# Usage: tools/GenerateGoldens/generate.sh <path-to-tiff-ios checkout>
#
# The checkout should be NGA tiff-ios 4.0.3 (the ObjC library SwiftTiff was
# ported from). Nothing in it is modified; the binary is built in a temp dir.
set -eu

TIFF_IOS=${1:?usage: $0 <path-to-tiff-ios checkout>}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

xcrun clang -fobjc-arc -O2 \
    -framework Foundation -lz \
    -I "$TIFF_IOS/tiff-ios/include" \
    $(find "$TIFF_IOS/tiff-ios" -name '*.m') \
    "$ROOT/tools/GenerateGoldens/main.m" \
    -o "$BUILD/GenerateGoldens"

"$BUILD/GenerateGoldens" "$ROOT/Tests/SwiftTiffTests/Fixtures" "$ROOT/Tests/SwiftTiffTests/Goldens"
