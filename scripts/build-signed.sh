#!/bin/bash
set -euo pipefail

# VoiceInk signed-release build (fork-only).
#
# Produces a Developer ID-signed, hardened-runtime, notarized, universal
# (arm64 + x86_64) DMG that installs on another Mac without Gatekeeper prompts.
# Keeps LOCAL_BUILD on (no license, no CloudKit) and uses the local
# entitlements (no iCloud/Keychain/Push; mic, apple-events, screen-capture).
# The bundle ID comes from Fork.local.xcconfig, as for every build.
#
# Configuration: set these in the environment or in scripts/local.env
# (gitignored; copy scripts/local.env.example):
#   APPLE_ID                Apple ID used for notarization
#   TEAM_ID                 Apple Developer team ID
#   DEVELOPER_ID_IDENTITY   "Developer ID Application: <Name> (<TEAM_ID>)"
#   NOTARY_PROFILE          notarytool keychain profile name
#   NOTARY_PASSWORD_OP_REF  optional 1Password secret reference for `op read` to the
#                           app-specific password; used to recreate a missing
#                           NOTARY_PROFILE
#
# If notarization fails with HTTP 403 "a required agreement is missing or has
# expired", accept the updated agreement at both developer.apple.com/account
# and appstoreconnect.apple.com (the App Store Connect modal is the usual one).

APP_NAME="VoiceInk"
SCHEME="VoiceInk"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOCAL_ENV="${SCRIPT_DIR}/local.env"
# shellcheck source=/dev/null
if [ -f "$LOCAL_ENV" ]; then . "$LOCAL_ENV"; fi

missing=()
for var in APPLE_ID TEAM_ID DEVELOPER_ID_IDENTITY NOTARY_PROFILE; do
  [ -n "${!var:-}" ] || missing+=("$var")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: missing signing configuration: ${missing[*]}" >&2
  echo "Set it in the environment or in ${LOCAL_ENV} (copy scripts/local.env.example)." >&2
  exit 1
fi
IDENTITY="$DEVELOPER_ID_IDENTITY"
NOTARIZE_PROFILE="$NOTARY_PROFILE"

BUILD_ROOT="${PROJECT_DIR}/build"
DERIVED_DATA_PATH="${BUILD_ROOT}/derived-data/signed"
ARTIFACTS_DIR="${BUILD_ROOT}/releases"
ENTITLEMENTS="${PROJECT_DIR}/VoiceInk/VoiceInk.local.entitlements"
DMG_BACKGROUND="${SCRIPT_DIR}/dmg-assets/dmg-background.png"

cd "$PROJECT_DIR"

require_command() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }
require_file()    { [ -e "$1" ] || { echo "ERROR: missing file: $1" >&2; exit 1; }; }

echo "==> Checking prerequisites..."
require_command xcodebuild
require_command codesign
require_command hdiutil
require_command ditto
require_command lipo
require_command spctl
require_command xcrun
require_command python3
python3 -c "import dmgbuild" 2>/dev/null || { echo "ERROR: dmgbuild not installed — run: python3 -m pip install --user dmgbuild" >&2; exit 1; }
require_file "$ENTITLEMENTS"
require_file "$DMG_BACKGROUND"
require_file "${SCRIPT_DIR}/dmg-assets/settings.py"

if ! security find-identity -v -p codesigning | grep -Fq "$IDENTITY"; then
  echo "ERROR: Developer ID identity not found in Keychain: $IDENTITY" >&2
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$NOTARIZE_PROFILE" >/dev/null 2>&1; then
  if [ -n "${NOTARY_PASSWORD_OP_REF:-}" ] && command -v op >/dev/null 2>&1; then
    echo "==> notary profile '$NOTARIZE_PROFILE' missing; recreating it from 1Password..." >&2
    if ASP="$(op read "$NOTARY_PASSWORD_OP_REF" 2>/dev/null)" && [ -n "$ASP" ]; then
      xcrun notarytool store-credentials "$NOTARIZE_PROFILE" \
        --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$ASP" >/dev/null 2>&1 || true
    fi
    unset ASP
  fi
  if ! xcrun notarytool history --keychain-profile "$NOTARIZE_PROFILE" >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: notarytool keychain profile "$NOTARIZE_PROFILE" is unavailable.

Recreate it with an app-specific password (account.apple.com -> Sign-In and
Security -> App-Specific Passwords):
  xcrun notarytool store-credentials "$NOTARIZE_PROFILE" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password <password>
If that returns HTTP 403 about a missing or expired agreement, accept the
agreement at developer.apple.com/account and appstoreconnect.apple.com, then retry.
EOF
    exit 1
  fi
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/${APP_NAME}.app"

echo "==> Building universal Release (arm64 + x86_64) with Developer ID + hardened runtime..."
xcodebuild \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  -project "${APP_NAME}.xcodeproj" -scheme "$SCHEME" -configuration Release \
  clean build \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCAL_BUILD' \
  2>&1 | tail -8

[ -d "$APP_PATH" ] || { echo "ERROR: build failed — $APP_PATH not found" >&2; exit 1; }

echo "==> Re-signing inside-out (Developer ID + hardened runtime + timestamp)..."
# xcodebuild does NOT re-sign code nested inside frameworks. Sparkle ships its
# Autoupdate, Updater.app, and XPC services without a Developer ID signature +
# secure timestamp, which fails notarization. Sign every nested binary
# inside-out (deepest first), then the app last with clean entitlements (which
# also strips the get-task-allow debug entitlement).
sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"; }
FW="${APP_PATH}/Contents/Frameworks"
find "$FW" -name "*.xpc" -print0 2>/dev/null | while IFS= read -r -d '' x; do sign "$x"; done
find "$FW" -name "*.app" -print0 2>/dev/null | while IFS= read -r -d '' a; do
  exe="$a/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$a/Contents/Info.plist" 2>/dev/null)"
  [ -e "$exe" ] && sign "$exe"
  sign "$a"
done
find "$FW" -name "Autoupdate" -type f -print0 2>/dev/null | while IFS= read -r -d '' u; do sign "$u"; done
find "$FW" -name "*.dylib" -print0 2>/dev/null | while IFS= read -r -d '' d; do sign "$d"; done
find "$FW" -maxdepth 1 -name "*.framework" -print0 2>/dev/null | while IFS= read -r -d '' f; do sign "$f"; done
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_PATH"

echo "==> Verifying universal binary..."
lipo -info "${APP_PATH}/Contents/MacOS/${APP_NAME}"

echo "==> Verifying code signature + hardened runtime + timestamp..."
codesign --verify --deep --strict "$APP_PATH"
SIG="$(codesign --display --verbose=4 "$APP_PATH" 2>&1)"
printf '%s\n' "$SIG" | grep -E "Authority=|Timestamp=|TeamIdentifier=|flags="
printf '%s\n' "$SIG" | grep -q '^Timestamp=' || { echo "ERROR: missing secure timestamp" >&2; exit 1; }
printf '%s\n' "$SIG" | grep -q 'runtime' || { echo "ERROR: hardened runtime not enabled" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")"
DMG_PATH="${ARTIFACTS_DIR}/${APP_NAME}-${VERSION}-signed.dmg"

echo "==> Creating styled DMG (${APP_NAME} ${VERSION})..."
# dmgbuild writes the .DS_Store directly, so the picture background applies
# reliably (Finder AppleScript-based tools fall back to a solid color on recent
# macOS). It auto-detects [email protected] for Retina.
# Geometry is hand-aligned with scripts/dmg-assets/make-dmg-background.swift.
hdiutil detach "/Volumes/${APP_NAME}" >/dev/null 2>&1 || true
rm -f "$DMG_PATH"
mkdir -p "$ARTIFACTS_DIR"
DMG_APP="$APP_PATH" DMG_BG="$DMG_BACKGROUND" \
  python3 -c "import dmgbuild; dmgbuild.build_dmg('${DMG_PATH}', '${APP_NAME}', settings_file='${SCRIPT_DIR}/dmg-assets/settings.py')"
hdiutil verify "$DMG_PATH"

echo "==> Signing DMG..."
codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose=4 "$DMG_PATH"

echo "==> Notarizing (1-5 min)..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARIZE_PROFILE" --wait

echo "==> Stapling + validating..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo
echo "Done! Shareable notarized DMG:"
echo "  ${DMG_PATH}"
