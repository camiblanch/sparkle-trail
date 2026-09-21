#!/bin/bash
# Assembles "Sparkle Trail.app" from the SwiftPM executable. Command Line Tools
# are enough; a full Xcode install is not required. Two gaps in the Command Line
# Tools need a workaround. A comment marks each one.
#
#   ./build.sh              native architecture only
#   UNIVERSAL=1 ./build.sh  arm64 + x86_64, for the downloadable build
#   SDKROOT=... ./build.sh  build against a specific SDK
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${CONFIG:-release}"
DEPLOY_TARGET="14.0"
APP="$ROOT/build/Sparkle Trail.app"

common=(-c "$CONFIG" --disable-sandbox --package-path "$ROOT")

# The Swift Build engine reads platform bundles from a Platforms directory, and
# the Command Line Tools ship none, so fall back to the older SwiftPM engine.
if [ ! -d "$(xcode-select -p)/Platforms" ]; then
    common+=(--build-system native)
fi

# From the macOS 27 SDK on, `@State` is a macro rather than a property wrapper,
# and the Command Line Tools ship no SwiftUIMacros plugin to expand it. Build
# against the newest installed SDK that still compiles a SwiftUI view.
sdk_builds_swiftui() {
    printf 'import SwiftUI\nstruct Probe: View {\n@State private var value = 0\nvar body: some View { EmptyView() }\n}\n' |
        xcrun swiftc -typecheck -sdk "$1" \
            -target "$(uname -m)-apple-macosx$DEPLOY_TARGET" - >/dev/null 2>&1
}

if [ -z "${SDKROOT:-}" ]; then
    sdk_dir="$(dirname "$(xcrun --show-sdk-path)")"
    while IFS= read -r candidate; do
        if sdk_builds_swiftui "$candidate"; then
            export SDKROOT="$candidate"
            break
        fi
    done < <(find "$sdk_dir" -maxdepth 1 -type d -name 'MacOSX*.sdk' | sort -rV)

    if [ -z "${SDKROOT:-}" ]; then
        echo "error: no SDK in $sdk_dir compiles SwiftUI; install Xcode" >&2
        exit 1
    fi
fi

echo "sdk: $SDKROOT"

swift build "${common[@]}"
native="$(swift build "${common[@]}" --show-bin-path)/SparkleTrail"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    # The second slice is a separate cross build into its own scratch path,
    # rather than SwiftPM's --arch, so each slice keeps its own build cache.
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
