#!/bin/bash
set -euo pipefail

APP_PATH="${1:?app path required}"
EXPECTED="${2:-15.0}"
MAX_DEVICE_IOS="${3:-17.0}"
REPORT="${4:-min-os-report.log}"
BUILD_LOG="${5:-}"
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

extract_ios_min_versions() {
  local output="$1"
  if grep -q 'LC_BUILD_VERSION' <<< "$output"; then
    awk '$1 == "minos" {print $2}' <<< "$output" | sort -u
  elif grep -q 'LC_VERSION_MIN_IPHONEOS' <<< "$output"; then
    awk '$1 == "version" {print $2; exit}' <<< "$output"
  fi
}

resolve_embedded_dependency() {
  local binary="$1" dependency="$2" candidate=""
  case "$dependency" in
    @rpath/*) candidate="$APP_PATH/Frameworks/${dependency#@rpath/}" ;;
    @executable_path/*) candidate="$APP_PATH/${dependency#@executable_path/}" ;;
    @loader_path/*) candidate="$(dirname "$binary")/${dependency#@loader_path/}" ;;
    *) return 1 ;;
  esac
  [[ -f "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

[[ -d "$APP_PATH" ]] || fail "App directory does not exist: $APP_PATH"
[[ -f "$PLIST" ]] || fail "Info.plist does not exist: $PLIST"

ACTUAL=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST" 2>/dev/null || true)
EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null || true)
ROOT_BINARY="$APP_PATH/$EXECUTABLE"

echo "App MinimumOSVersion: $ACTUAL" | tee -a "$REPORT"
echo "Expected project minimum: $EXPECTED" | tee -a "$REPORT"
echo "Required iOS 17 device ceiling: $MAX_DEVICE_IOS" | tee -a "$REPORT"
echo "App executable: $EXECUTABLE" | tee -a "$REPORT"
[[ -n "$ACTUAL" ]] || fail "Built app has no MinimumOSVersion"
[[ "$ACTUAL" = "$EXPECTED" ]] || fail "App MinimumOSVersion mismatch: expected $EXPECTED, got $ACTUAL"
[[ -n "$EXECUTABLE" && -f "$ROOT_BINARY" ]] || fail "Built app executable is missing: $ROOT_BINARY"

QUEUE=$(mktemp)
VISITED=$(mktemp)
trap 'rm -f "$QUEUE" "$VISITED"' EXIT
printf '%s\n' "$ROOT_BINARY" > "$QUEUE"

HIGHER_THAN_EXPECTED=0
HIGHER_THAN_DEVICE=0
RUNTIME_INSPECTED=0

while IFS= read -r binary; do
  [[ -n "$binary" ]] || continue
  if grep -Fxq "$binary" "$VISITED" 2>/dev/null; then continue; fi
  printf '%s\n' "$binary" >> "$VISITED"
  if ! file "$binary" | grep -q 'Mach-O'; then
    echo "WARN runtime dependency is not Mach-O: ${binary#"$APP_PATH"/}" | tee -a "$REPORT"
    continue
  fi

  RUNTIME_INSPECTED=$((RUNTIME_INSPECTED + 1))
  rel="${binary#"$APP_PATH"/}"
  output="$(xcrun vtool -show-build "$binary" 2>/dev/null || true)"
  minos_values="$(extract_ios_min_versions "$output")"
  if [[ -z "$minos_values" ]]; then
    echo "WARN no iOS minimum-version load command found for runtime binary: $rel" | tee -a "$REPORT"
  else
    while IFS= read -r minos; do
      [[ -n "$minos" ]] || continue
      echo "Runtime Mach-O minOS $minos: $rel" | tee -a "$REPORT"
      if version_gt "$minos" "$MAX_DEVICE_IOS"; then
        echo "ERROR runtime binary requires iOS $minos, above required iOS $MAX_DEVICE_IOS: $rel" | tee -a "$REPORT" >&2
        HIGHER_THAN_DEVICE=$((HIGHER_THAN_DEVICE + 1))
      elif version_gt "$minos" "$EXPECTED"; then
        echo "ERROR runtime binary requires iOS $minos, above project Deployment Target $EXPECTED: $rel" | tee -a "$REPORT" >&2
        HIGHER_THAN_EXPECTED=$((HIGHER_THAN_EXPECTED + 1))
      fi
    done <<< "$minos_values"
  fi

  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    candidate="$(resolve_embedded_dependency "$binary" "$dependency" || true)"
    if [[ -n "$candidate" ]] && ! grep -Fxq "$candidate" "$VISITED" 2>/dev/null; then
      printf '%s\n' "$candidate" >> "$QUEUE"
    fi
  done < <(otool -L "$binary" 2>/dev/null | tail -n +2 | awk '{print $1}')
done < "$QUEUE"

echo "Runtime Mach-O files inspected: $RUNTIME_INSPECTED" | tee -a "$REPORT"

UNREFERENCED=0
SYNTHETIC_STUBS=0
if [[ -d "$APP_PATH/Frameworks" ]]; then
  while IFS= read -r -d '' binary; do
    if ! file "$binary" | grep -q 'Mach-O'; then continue; fi
    if grep -Fxq "$binary" "$VISITED" 2>/dev/null; then continue; fi
    UNREFERENCED=$((UNREFERENCED + 1))
    rel="${binary#"$APP_PATH"/}"
    output="$(xcrun vtool -show-build "$binary" 2>/dev/null || true)"
    minos_values="$(extract_ios_min_versions "$output" | paste -sd, -)"
    if [[ "$minos_values" == "100.0" ]]; then
      SYNTHETIC_STUBS=$((SYNTHETIC_STUBS + 1))
      echo "INFO skipped unreferenced Xcode codeless/static-framework stub minOS=100.0: $rel" | tee -a "$REPORT"
    else
      echo "INFO skipped unreferenced embedded Mach-O minOS=${minos_values:-unknown}: $rel" | tee -a "$REPORT"
    fi
  done < <(find "$APP_PATH/Frameworks" -type f -print0)
fi

echo "Unreferenced embedded Mach-O files skipped: $UNREFERENCED (Xcode 100.0 stubs: $SYNTHETIC_STUBS)" | tee -a "$REPORT"

STATIC_WARNING_EXPECTED=0
STATIC_WARNING_DEVICE=0
if [[ -n "$BUILD_LOG" && -f "$BUILD_LOG" ]]; then
  while IFS= read -r line; do
    version="$(printf '%s\n' "$line" | sed -nE "s/.*built for newer 'iOS' version \(([0-9.]+)\).*/\1/p")"
    [[ -n "$version" ]] || continue
    echo "Linker static-object compatibility warning: iOS $version :: $line" | tee -a "$REPORT"
    if version_gt "$version" "$MAX_DEVICE_IOS"; then
      STATIC_WARNING_DEVICE=$((STATIC_WARNING_DEVICE + 1))
    elif version_gt "$version" "$EXPECTED"; then
      STATIC_WARNING_EXPECTED=$((STATIC_WARNING_EXPECTED + 1))
    fi
  done < <(grep -F "was built for newer 'iOS' version" "$BUILD_LOG" || true)
fi

if ((HIGHER_THAN_DEVICE > 0)); then fail "$HIGHER_THAN_DEVICE runtime Mach-O dependency slice(s) require newer than iOS $MAX_DEVICE_IOS"; fi
if ((HIGHER_THAN_EXPECTED > 0)); then fail "$HIGHER_THAN_EXPECTED runtime Mach-O dependency slice(s) require newer than project Deployment Target iOS $EXPECTED"; fi
if ((STATIC_WARNING_DEVICE > 0)); then fail "$STATIC_WARNING_DEVICE linked static object(s) were built for newer than required device iOS $MAX_DEVICE_IOS"; fi
if ((STATIC_WARNING_EXPECTED > 0)); then fail "$STATIC_WARNING_EXPECTED linked static object(s) were built for newer than project Deployment Target iOS $EXPECTED"; fi

echo "Minimum OS compatibility audit: OK" | tee -a "$REPORT"
