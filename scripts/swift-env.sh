# Sourced by build.sh and test.sh. Leaves its results in SDKROOT,
# SWIFT_ENGINE_FLAGS and SWIFT_TESTING_FLAGS.
#
# A full Xcode install needs none of this. The Command Line Tools have three
# gaps, so each one is probed for rather than assumed, and the same scripts run
# unchanged on a developer machine and on a CI runner. A comment marks each gap.
#
# macOS ships bash 3.2, which treats an empty array as unset under `set -u`, so
# callers expand these with ${name[@]+"${name[@]}"}.

DEPLOY_TARGET="${DEPLOY_TARGET:-14.0}"
DEVELOPER_DIR_PATH="$(xcode-select -p)"
TARGET_TRIPLE="$(uname -m)-apple-macosx$DEPLOY_TARGET"

SWIFT_ENGINE_FLAGS=()
SWIFT_TESTING_FLAGS=()

compiles() {
    local source="$1"
    shift
    printf '%s' "$source" |
        xcrun swiftc -typecheck -target "$TARGET_TRIPLE" "$@" - >/dev/null 2>&1
}

SWIFTUI_PROBE='import SwiftUI
struct Probe: View {
@State private var value = 0
var body: some View { EmptyView() }
}
'

TESTING_PROBE='import Testing
@Test func probe() { #expect(Bool(true)) }
'

# A full Xcode install has a Platforms directory. It carries the platform
# bundles, the SwiftUI macro plugin and the swift-testing framework, and SwiftPM
# finds all three on its own, so the probes below run for the Command Line Tools
# only. A plain `swiftc` probe does not search the Xcode platform paths, so on a
# full install it reports a gap that SwiftPM does not have.
if [ ! -d "$DEVELOPER_DIR_PATH/Platforms" ]; then
    # The Swift Build engine reads platform bundles from a Platforms directory,
    # so fall back to the older SwiftPM engine.
    SWIFT_ENGINE_FLAGS+=(--build-system native)

    # From the macOS 27 SDK on, `@State` is a macro rather than a property
    # wrapper, and the Command Line Tools ship no SwiftUIMacros plugin to expand
    # it. When the default SDK cannot expand it, drop to the newest installed
    # SDK that can.
    if [ -z "${SDKROOT:-}" ] && ! compiles "$SWIFTUI_PROBE"; then
        sdk_dir="$(dirname "$(xcrun --show-sdk-path)")"
        while IFS= read -r candidate; do
            if compiles "$SWIFTUI_PROBE" -sdk "$candidate"; then
                export SDKROOT="$candidate"
                break
            fi
        done < <(find "$sdk_dir" -maxdepth 1 -type d -name 'MacOSX*.sdk' | sort -rV)

        if [ -z "${SDKROOT:-}" ]; then
            echo "error: no SDK in $sdk_dir compiles SwiftUI; install Xcode" >&2
            exit 1
        fi
    fi

    # swift-testing ships as a framework outside the SDK, and its macro plugin
    # sits in a subdirectory the compiler does not search, so both are pointed
    # at when `import Testing` does not resolve on its own.
    if ! compiles "$TESTING_PROBE"; then
        testing_frameworks="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
        testing_plugins="$DEVELOPER_DIR_PATH/usr/lib/swift/host/plugins/testing"
        SWIFT_TESTING_FLAGS=(
            -Xswiftc -F -Xswiftc "$testing_frameworks"
            -Xswiftc -plugin-path -Xswiftc "$testing_plugins"
            -Xlinker -rpath -Xlinker "$testing_frameworks"
        )

        if ! compiles "$TESTING_PROBE" -F "$testing_frameworks" -plugin-path "$testing_plugins"; then
            echo "error: swift-testing is unavailable in $DEVELOPER_DIR_PATH" >&2
            exit 1
        fi
    fi
fi
