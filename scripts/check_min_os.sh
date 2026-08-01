#!/bin/bash
set -euo pipefail

APP_PATH="${1:?app path required}"
EXPECTED="${2:-15.0}"
PLIST="$APP_PATH/Info.plist"

test -f "$PLIST"
ACTUAL=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST")
echo "App MinimumOSVersion: $ACTUAL"
echo "Expected: $EXPECTED"

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "Unexpected MinimumOSVersion: $ACTUAL" >&2
  exit 1
fi

APP_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")
BINARY="$APP_PATH/$APP_NAME"
test -f "$BINARY"

echo "Main executable build version:"
xcrun vtool -show-build "$BINARY"

while IFS= read -r -d '' framework; do
  name="$(basename "$framework" .framework)"
  binary="$framework/$name"
  if [[ -f "$binary" ]]; then
    echo "Framework: $name"
    xcrun vtool -show-build "$binary"
  fi
done < <(find "$APP_PATH/Frameworks" -maxdepth 1 -name '*.framework' -print0 2>/dev/null || true)
