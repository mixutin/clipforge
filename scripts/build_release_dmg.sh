#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/Clipforge"
BUILD_ROOT="${1:-$ROOT_DIR/build/release}"
DERIVED_DATA_DIR="$BUILD_ROOT/DerivedData"

mkdir -p "$BUILD_ROOT"

(
  cd "$PROJECT_DIR"
  xcodegen generate
)
xcodebuild \
  -project "$PROJECT_DIR/Clipforge.xcodeproj" \
  -scheme Clipforge \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/Clipforge.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Clipforge.app was not produced at the expected path." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
OUTPUT_DMG="$BUILD_ROOT/Clipforge-$VERSION.dmg"

"$ROOT_DIR/scripts/create_dmg.sh" "$APP_PATH" "$OUTPUT_DMG" >/dev/null

echo "APP_PATH=$APP_PATH"
echo "DMG_PATH=$OUTPUT_DMG"
