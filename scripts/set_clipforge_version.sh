#!/bin/bash

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <marketing-version> [build-number]" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/Clipforge/project.yml"
MARKETING_VERSION="$1"
CURRENT_BUILD="$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION: //p' "$PROJECT_FILE" | head -n 1)"
BUILD_NUMBER="${2:-$((CURRENT_BUILD + 1))}"

if ! [[ "$MARKETING_VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Marketing version must look like 0.2.0 or 1.0." >&2
  exit 1
fi

if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Build number must be a positive integer." >&2
  exit 1
fi

MARKETING_VERSION="$MARKETING_VERSION" BUILD_NUMBER="$BUILD_NUMBER" perl -0pi -e '
  s/(CURRENT_PROJECT_VERSION:\s*)\d+/${1}$ENV{BUILD_NUMBER}/g;
  s/(MARKETING_VERSION:\s*)[0-9]+(?:\.[0-9]+){1,2}/${1}$ENV{MARKETING_VERSION}/g;
' "$PROJECT_FILE"

(
  cd "$ROOT_DIR/Clipforge"
  xcodegen generate
)

echo "Updated Clipforge to version $MARKETING_VERSION ($BUILD_NUMBER)."
