#!/bin/bash
# Assembles "Sparkle Trail.app" from the SwiftPM executable. Command Line Tools
# are enough; a full Xcode install is not required.
#
#   ./build.sh              native architecture only
#   UNIVERSAL=1 ./build.sh  arm64 + x86_64, for the downloadable build
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${CONFIG:-release}"
DEPLOY_TARGET="14.0"
APP="$ROOT/build/Sparkle Trail.app"

common=(-c "$CONFIG" --disable-sandbox --package-path "$ROOT")

swift build "${common[@]}"
native="$(swift build "${common[@]}" --show-bin-path)/SparkleTrail"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    # SwiftPM's own --arch needs xcbuild, which ships with Xcode rather than the
    # Command Line Tools, so the second slice is a separate cross build.
    if [ "$(uname -m)" = "arm64" ]; then
        other_arch="x86_64"
    else
        other_arch="arm64"
    fi
    cross=("${common[@]}" --scratch-path "$ROOT/.build-$other_arch"
           -Xswiftc -target -Xswiftc "$other_arch-apple-macosx$DEPLOY_TARGET")
    swift build "${cross[@]}"
    other="$(swift build "${cross[@]}" --show-bin-path)/SparkleTrail"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    lipo -create -output "$APP/Contents/MacOS/SparkleTrail" "$native" "$other"
else
    cp "$native" "$APP/Contents/MacOS/SparkleTrail"
fi

# Ad-hoc signature: enough for local use and for SMAppService login items. It is
# not a Developer ID signature, so a downloaded copy still needs the Gatekeeper
# step described in the README.
codesign --force --sign - "$APP" >/dev/null 2>&1 ||
    echo "warning: ad-hoc codesign failed; the app still runs locally"

echo "built: $APP ($(lipo -archs "$APP/Contents/MacOS/SparkleTrail"))"
