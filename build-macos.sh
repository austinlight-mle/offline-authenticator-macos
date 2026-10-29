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

cd "$ROOT"
echo "Building Authenticator $VERSION ($CONFIGURATION) for macOS..."
xcodebuild \
    -project Authenticator.xcodeproj \
    -scheme Authenticator \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    MARKETING_VERSION="$VERSION" \
    build 2>&1 | grep -E "error:|warning: .*Authenticator/|BUILD " || true
STATUS=${PIPESTATUS[0]}

BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Authenticator.app"
if [ "$STATUS" -ne 0 ] || [ ! -d "$BUILT_APP" ]; then
    echo "Build failed (xcodebuild exit code $STATUS)" >&2
    exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/$APP_NAME"
cp -R "$BUILT_APP" "$DIST/$APP_NAME"
echo "Done: $DIST/$APP_NAME"
