#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/CTT Pulse.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
PRIVACY_MANIFEST="$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
ENTITLEMENTS="$ROOT_DIR/Config/AppStore/CTTPulse.entitlements"
SOURCE_APP_ICONSET="$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
SOURCE_LOCAL_ICON="$ROOT_DIR/Resources/CTTPulse.icns"
BUILT_LOCAL_ICON="$APP_BUNDLE/Contents/Resources/CTTPulse.icns"
STRICT="${1:-}"

warnings=0
failures=0

warn() {
  warnings=$((warnings + 1))
  printf 'WARN: %s\n' "$1" >&2
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ ! -e "$path" ]]; then
    fail "$label is missing: $path"
  fi
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

printf 'CTT Pulse App Store preflight\n'
printf 'Root: %s\n\n' "$ROOT_DIR"

require_file "$APP_BUNDLE" "Built app bundle"
require_file "$INFO_PLIST" "Info.plist"
require_file "$ENTITLEMENTS" "App Store entitlements"
require_file "$SOURCE_APP_ICONSET" "Xcode app icon asset set"
require_file "$SOURCE_LOCAL_ICON" "Local SwiftPM bundle icon"

if [[ -e "$INFO_PLIST" ]]; then
  plutil -lint "$INFO_PLIST" >/dev/null

  for key in CFBundleIdentifier CFBundleName CFBundleExecutable CFBundleShortVersionString CFBundleVersion LSApplicationCategoryType LSMinimumSystemVersion; do
    if [[ -z "$(plist_value "$key")" ]]; then
      fail "Info.plist is missing $key"
    fi
  done

  if [[ -z "$(plist_value CFBundleIconFile)" ]]; then
    warn "Info.plist is missing CFBundleIconFile for the local SwiftPM bundle."
  fi
fi

if [[ -d "$SOURCE_APP_ICONSET" ]]; then
  icon_png_count="$(find "$SOURCE_APP_ICONSET" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
  if [[ "$icon_png_count" != "10" ]]; then
    fail "AppIcon.appiconset should contain 10 macOS PNG renditions, found $icon_png_count"
  fi
fi

if [[ -d "$APP_BUNDLE" && ! -e "$BUILT_LOCAL_ICON" ]]; then
  warn "Built local app is missing CTTPulse.icns. Run ./script/build_and_run.sh after updating resources."
fi

if [[ -e "$ENTITLEMENTS" ]]; then
  plutil -lint "$ENTITLEMENTS" >/dev/null

  if ! /usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "$ENTITLEMENTS" >/dev/null 2>&1; then
    fail "App Store entitlements must enable com.apple.security.app-sandbox"
  fi

  if ! /usr/libexec/PlistBuddy -c "Print :com.apple.security.network.client" "$ENTITLEMENTS" >/dev/null 2>&1; then
    fail "CTT API access needs com.apple.security.network.client"
  fi
fi

if [[ -e "$PRIVACY_MANIFEST" ]]; then
  plutil -lint "$PRIVACY_MANIFEST" >/dev/null
else
  warn "Privacy manifest is not in the built app. Run ./script/build_and_run.sh after updating resources."
fi

if [[ -d "$APP_BUNDLE" ]]; then
  signing_output="$(codesign -dvvv --entitlements :- "$APP_BUNDLE" 2>&1 || true)"
  if grep -q "Signature=adhoc" <<<"$signing_output"; then
    warn "Built app is ad-hoc signed. App Store upload needs an Apple distribution identity and provisioning profile."
  fi

  if ! grep -q "TeamIdentifier=" <<<"$signing_output" || grep -q "TeamIdentifier=not set" <<<"$signing_output"; then
    warn "Built app has no TeamIdentifier. This is expected for local builds, but not for App Store archives."
  fi
fi

identities="$(security find-identity -p codesigning -v 2>/dev/null || true)"
if ! grep -Eq "Apple Distribution|3rd Party Mac Developer Application" <<<"$identities"; then
  warn "No App Store distribution signing identity was found in this keychain."
fi

if ! find "$ROOT_DIR" -maxdepth 2 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) | grep -q .; then
  warn "No Xcode project/workspace exists yet. App Store archiving should use an Xcode app target."
fi

printf '\nPreflight complete: %d failure(s), %d warning(s).\n' "$failures" "$warnings"

if [[ "$STRICT" == "--strict" && $((failures + warnings)) -gt 0 ]]; then
  exit 1
fi

if [[ $failures -gt 0 ]]; then
  exit 1
fi
