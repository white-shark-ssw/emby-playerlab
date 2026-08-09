#!/bin/bash
set -euo pipefail

APP_PATH="${1:?app path required}"
EXPECTED="${2:-15.0}"
MAX_DEVICE_IOS="${3:-17.0}"
REPORT="${4:-min-os-report.log}"
PLIST="$APP_PATH/Info.plist"

: > "$REPORT"

fail() {
  echo "::error::$1" | tee -a "$REPORT" >&2
  exit 1
}

version_gt() {
  local a="$1" b="$2"
  local a1=0 a2=0 a3=0 b1=0 b2=0 b3=0
  IFS=. read -r a1 a2 a3 <<< "$a"
  IFS=. read -r b1 b2 b3 <<< "$b"
  a1=${a1:-0}; a2=${a2:-0}; a3=${a3:-0}
  b1=${b1:-0}; b2=${b2:-0}; b3=${b3:-0}
  if ((10#$a1 > 10#$b1)); then return 0; fi
  if ((10#$a1 < 10#$b1)); then return 1; fi
  if ((10#$a2 > 10#$b2)); then return 0; fi
  if ((10#$a2 < 10#$b2)); then return 1; fi
  ((10#$a3 > 10#$b3))
}

[[ -d "$APP_PATH" ]] || fail "App directory does not exist: $APP_PATH"
[[ -f "$PLIST" ]] || fail "Info.plist does not exist: $PLIST"

ACTUAL=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST" 2>/dev/null || true)
echo "App MinimumOSVersion: $ACTUAL" | tee -a "$REPORT"
echo "Expected project minimum: $EXPECTED" | tee -a "$REPORT"
echo "Required iOS 17 device ceiling: $MAX_DEVICE_IOS" | tee -a "$REPORT"
[[ -n "$ACTUAL" ]] || fail "Built app has no MinimumOSVersion"
[[ "$ACTUAL" = "$EXPECTED" ]] || fail "App MinimumOSVersion mismatch: expected $EXPECTED, got $ACTUAL"

HIGHER_THAN_EXPECTED=0
HIGHER_THAN_DEVICE=0
INSPECTED=0

while IFS= read -r -d '' binary; do
  if ! file "$binary" | grep -q 'Mach-O'; then
    continue
  fi
  INSPECTED=$((INSPECTED + 1))
  rel="${binary#"$APP_PATH"/}"
  output="$(xcrun vtool -show-build "$binary" 2>/dev/null || true)"
  minos_values="$(printf '%s\n' "$output" | awk '$1 == "minos" {print $2}' | sort -u)"
  if [[ -z "$minos_values" ]]; then
    echo "WARN no LC_BUILD_VERSION minos found: $rel" | tee -a "$REPORT"
    continue
  fi

  while IFS= read -r minos; do
    [[ -n "$minos" ]] || continue
    echo "Mach-O minOS $minos: $rel" | tee -a "$REPORT"
    if version_gt "$minos" "$MAX_DEVICE_IOS"; then
      echo "ERROR binary requires iOS $minos, above required iOS $MAX_DEVICE_IOS device compatibility: $rel" | tee -a "$REPORT" >&2
      HIGHER_THAN_DEVICE=$((HIGHER_THAN_DEVICE + 1))
    elif version_gt "$minos" "$EXPECTED"; then
      echo "ERROR binary requires iOS $minos, above project Deployment Target $EXPECTED: $rel" | tee -a "$REPORT" >&2
      HIGHER_THAN_EXPECTED=$((HIGHER_THAN_EXPECTED + 1))
    fi
  done <<< "$minos_values"
done < <(find "$APP_PATH" -type f -print0)

echo "Inspected Mach-O files: $INSPECTED" | tee -a "$REPORT"
if ((HIGHER_THAN_DEVICE > 0)); then
  fail "$HIGHER_THAN_DEVICE embedded Mach-O slice(s) require newer than iOS $MAX_DEVICE_IOS"
fi
if ((HIGHER_THAN_EXPECTED > 0)); then
  fail "$HIGHER_THAN_EXPECTED embedded Mach-O slice(s) require newer than project Deployment Target iOS $EXPECTED"
fi

echo "Minimum OS compatibility audit: OK" | tee -a "$REPORT"
