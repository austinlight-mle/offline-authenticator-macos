#!/bin/bash
# Builds the macOS app and places it in ./dist.
#
#   ./build-macos.sh            # Debug build (signed to run locally, no Apple team needed)
#   ./build-macos.sh Release    # Release build (requires a signing team in Xcode)
#
# Output: dist/Altosec Authenticator.app
set -euo pipefail

CONFIGURATION="${1:-Debug}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$ROOT/build/DerivedData"
DIST="$ROOT/dist"
APP_NAME="Altosec Authenticator.app"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Authenticator.app"
LOG="$ROOT/build/logs/xcodebuild-macos-$CONFIGURATION.log"

cd "$ROOT"
if pgrep -x xcodebuild >/dev/null; then
    echo "Another xcodebuild is running; wait for it to finish (concurrent builds lock the build database)." >&2
    exit 1
fi
# Remove the previous product so a failed build can never ship a stale app.
rm -rf "$BUILT_APP"
mkdir -p "$(dirname "$LOG")"

echo "Building Authenticator $VERSION ($CONFIGURATION) for macOS..."
STATUS=0
xcodebuild \
    -project Authenticator.xcodeproj \
    -scheme Authenticator \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    MARKETING_VERSION="$VERSION" \
    build > "$LOG" 2>&1 || STATUS=$?
grep -E "error:|warning: .*Authenticator/|BUILD " "$LOG" | grep -v "CoreSimulator is out of date" || true

if [ "$STATUS" -ne 0 ] || [ ! -x "$BUILT_APP/Contents/MacOS/Authenticator" ]; then
    echo "Build failed (xcodebuild exit code $STATUS). Full log: $LOG" >&2
    exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/$APP_NAME"
cp -R "$BUILT_APP" "$DIST/$APP_NAME"
echo "Done: $DIST/$APP_NAME"
