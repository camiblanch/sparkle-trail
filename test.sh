#!/bin/bash
# Runs the swift-testing suite. Command Line Tools are enough; the SDK and
# framework workarounds live in scripts/swift-env.sh.
#
#   ./test.sh                     the whole suite
#   ./test.sh --filter Clamp      one suite or test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

source "$ROOT/scripts/swift-env.sh"

echo "sdk: ${SDKROOT:-$(xcrun --show-sdk-path)}"

swift test --disable-sandbox --package-path "$ROOT" \
    ${SWIFT_ENGINE_FLAGS[@]+"${SWIFT_ENGINE_FLAGS[@]}"} \
    ${SWIFT_TESTING_FLAGS[@]+"${SWIFT_TESTING_FLAGS[@]}"} \
    "$@"
