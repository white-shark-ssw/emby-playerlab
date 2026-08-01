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

inspect_binary() {
  local binary="$1"
  local label="$2"
  [[ -f "$binary" ]] || return 0
  if file "$binary" | grep -q 'Mach-O'; then
    echo "Mach-O: $label"
    xcrun vtool -show-build "$binary"
  fi
}

APP_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")
inspect_binary "$APP_PATH/$APP_NAME" "App/$APP_NAME"

while IFS= read -r -d '' framework; do
  name="$(basename "$framework" .framework)"
  inspect_binary "$framework/$name" "Framework/$name"
done < <(find "$APP_PATH" -type d -name '*.framework' -print0)

while IFS= read -r -d '' dylib; do
  inspect_binary "$dylib" "Dylib/$(basename "$dylib")"
done < <(find "$APP_PATH" -type f -name '*.dylib' -print0)
