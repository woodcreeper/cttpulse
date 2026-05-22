#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/CTT Pulse.xcodeproj"
EXPORT_OPTIONS="$ROOT_DIR/Config/DeveloperID/ExportOptions.plist"
ENTITLEMENTS="$ROOT_DIR/Config/AppStore/CTTPulse.entitlements"
NOTARY_PROFILE="${CTTPULSE_NOTARY_PROFILE:-cttpulse-notary}"
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

printf 'CTT Pulse Developer ID preflight\n'
printf 'Root: %s\n\n' "$ROOT_DIR"

require_file "$PROJECT" "Xcode project"
require_file "$EXPORT_OPTIONS" "Developer ID export options"
require_file "$ENTITLEMENTS" "App entitlements"

if [[ -e "$EXPORT_OPTIONS" ]]; then
  plutil -lint "$EXPORT_OPTIONS" >/dev/null

  method="$(/usr/libexec/PlistBuddy -c 'Print :method' "$EXPORT_OPTIONS" 2>/dev/null || true)"
  team_id="$(/usr/libexec/PlistBuddy -c 'Print :teamID' "$EXPORT_OPTIONS" 2>/dev/null || true)"
  signing_style="$(/usr/libexec/PlistBuddy -c 'Print :signingStyle' "$EXPORT_OPTIONS" 2>/dev/null || true)"

  [[ "$method" == "developer-id" ]] || fail "Developer ID export method must be developer-id."
  [[ "$team_id" == "33XYKMGGZ7" ]] || fail "Developer ID export teamID must be 33XYKMGGZ7."
  [[ "$signing_style" == "automatic" ]] || warn "Developer ID export signingStyle is not automatic."
fi

if [[ -e "$ENTITLEMENTS" ]]; then
  plutil -lint "$ENTITLEMENTS" >/dev/null

  if ! /usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$ENTITLEMENTS" >/dev/null 2>&1; then
    fail "Developer ID builds should keep App Sandbox enabled."
  fi

  if ! /usr/libexec/PlistBuddy -c 'Print :com.apple.security.network.client' "$ENTITLEMENTS" >/dev/null 2>&1; then
    fail "CTT API access needs com.apple.security.network.client."
  fi
fi

if ! xcodebuild -list -project "$PROJECT" >/dev/null; then
  fail "Xcode cannot read $PROJECT."
fi

if ! xcodebuild -list -project "$PROJECT" 2>/dev/null | grep -q "CTT Pulse"; then
  fail "Xcode scheme CTT Pulse was not found."
fi

identities="$(security find-identity -p codesigning -v 2>/dev/null || true)"
if ! grep -q "Developer ID Application" <<<"$identities"; then
  warn "No directly visible Developer ID Application identity was found in the login keychain. Xcode-managed signing can still export Developer ID builds when the Apple account is signed in."
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  fail "No valid notarytool Keychain profile named '$NOTARY_PROFILE'. Create it with xcrun notarytool store-credentials before packaging a release."
fi

printf '\nPreflight complete: %d failure(s), %d warning(s).\n' "$failures" "$warnings"

if [[ "$STRICT" == "--strict" && $((failures + warnings)) -gt 0 ]]; then
  exit 1
fi

if [[ $failures -gt 0 ]]; then
  exit 1
fi
