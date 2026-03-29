#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <path-to-app> <output-dmg>" >&2
  exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="$2"
APP_NAME="$(basename "$APP_PATH")"
VOLUME_NAME="${APP_NAME%.app}"
WORK_DIR="$(mktemp -d)"
STAGING_DIR="$WORK_DIR/staging"

cleanup() {
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDZO \
  "$OUTPUT_DMG" >/dev/null

echo "$OUTPUT_DMG"
