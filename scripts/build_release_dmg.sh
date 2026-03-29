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

XCODEBUILD_ARGS=(
  -project "$PROJECT_DIR/Clipforge.xcodeproj"
  -scheme Clipforge
  -configuration Release
  -derivedDataPath "$DERIVED_DATA_DIR"
  -destination "platform=macOS"
)

if [ -n "${CLIPFORGE_CODESIGN_IDENTITY:-}" ]; then
  XCODEBUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=${CLIPFORGE_CODESIGN_IDENTITY}"
    "OTHER_CODE_SIGN_FLAGS=--timestamp"
  )

  if [ -n "${CLIPFORGE_DEVELOPMENT_TEAM:-}" ]; then
    XCODEBUILD_ARGS+=("DEVELOPMENT_TEAM=${CLIPFORGE_DEVELOPMENT_TEAM}")
  fi
else
  XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/Clipforge.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Clipforge.app was not produced at the expected path." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
OUTPUT_DMG="$BUILD_ROOT/Clipforge-$VERSION.dmg"

"$ROOT_DIR/scripts/create_dmg.sh" "$APP_PATH" "$OUTPUT_DMG" >/dev/null

if [ -n "${CLIPFORGE_CODESIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$CLIPFORGE_CODESIGN_IDENTITY" --timestamp "$OUTPUT_DMG"
fi

echo "APP_PATH=$APP_PATH"
echo "DMG_PATH=$OUTPUT_DMG"
