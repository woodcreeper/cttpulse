#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/CTT Pulse.xcodeproj"
SCHEME="CTT Pulse"
CONFIGURATION="Release"
EXPORT_OPTIONS="$ROOT_DIR/Config/DeveloperID/ExportOptions.plist"
BUILD_ROOT="$ROOT_DIR/build/DeveloperID"
ARCHIVE_PATH="$BUILD_ROOT/CTT Pulse.xcarchive"
EXPORT_PATH="$BUILD_ROOT/Export"
STAGING_PATH="$BUILD_ROOT/DMGRoot"
NOTARY_PROFILE="${CTTPULSE_NOTARY_PROFILE:-cttpulse-notary}"
SKIP_TESTS=0
SKIP_NOTARIZATION=0

usage() {
  cat <<'USAGE'
Usage: script/package_developer_id.sh [options]

Builds a Developer ID signed, notarized CTT Pulse DMG for direct distribution.

Options:
  --skip-tests             Do not run swift test before archiving.
  --skip-notarization      Produce a local signed DMG without notarization.
                           Use only for packaging diagnostics, never release.
  --notary-profile NAME    Keychain profile for notarytool. Default: cttpulse-notary.
  -h, --help               Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:-}"
      if [[ -z "$NOTARY_PROFILE" ]]; then
        printf 'Missing value for --notary-profile\n' >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$PROJECT" ]]; then
  printf 'Missing Xcode project: %s\n' "$PROJECT" >&2
  exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  printf 'Missing Developer ID export options: %s\n' "$EXPORT_OPTIONS" >&2
  exit 1
fi

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    cat >&2 <<EOF
No valid notarytool Keychain profile named "$NOTARY_PROFILE".

Create it once with:
  xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
    --apple-id "YOUR_APPLE_ID_EMAIL" \\
    --team-id "62QT5L9L6J"

The command prompts securely for an app-specific password.
EOF
    exit 1
  fi
fi

if [[ "$SKIP_TESTS" -eq 0 ]]; then
  swift test
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

xcodebuild \
  -quiet \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

APP_PATH="$EXPORT_PATH/CTT Pulse.app"
if [[ ! -d "$APP_PATH" ]]; then
  printf 'Export did not produce %s\n' "$APP_PATH" >&2
  exit 1
fi

SIGNING_OUTPUT="$(codesign -dvvv --entitlements :- "$APP_PATH" 2>&1 || true)"
printf '%s\n' "$SIGNING_OUTPUT" > "$BUILD_ROOT/codesign.txt"

if ! grep -Eq "Authority=Developer ID Application: .+ \\(62QT5L9L6J\\)" <<<"$SIGNING_OUTPUT"; then
  printf 'Exported app is not signed with the expected Developer ID Application identity.\n' >&2
  printf '%s\n' "$SIGNING_OUTPUT" >&2
  exit 1
fi

if ! grep -q "TeamIdentifier=62QT5L9L6J" <<<"$SIGNING_OUTPUT"; then
  printf 'Exported app is missing the expected TeamIdentifier.\n' >&2
  printf '%s\n' "$SIGNING_OUTPUT" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE_PATH/Info.plist" 2>/dev/null || true)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE_PATH/Info.plist" 2>/dev/null || true)"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
fi
if [[ -z "$BUILD" ]]; then
  BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
fi

DMG_BASENAME="CTT Pulse-$VERSION+$BUILD"
DMG_PATH="$BUILD_ROOT/$DMG_BASENAME.dmg"

rm -rf "$STAGING_PATH"
mkdir -p "$STAGING_PATH"
ditto "$APP_PATH" "$STAGING_PATH/CTT Pulse.app"
ln -s /Applications "$STAGING_PATH/Applications"

hdiutil create \
  -volname "CTT Pulse" \
  -srcfolder "$STAGING_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl -a -vv --type open "$DMG_PATH"
else
  printf '\nWARNING: Skipped notarization. Do not publish this DMG to customers.\n' >&2
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

cat <<EOF

Developer ID package complete.
DMG:      $DMG_PATH
SHA-256:  $DMG_PATH.sha256
Codesign: $BUILD_ROOT/codesign.txt
EOF
