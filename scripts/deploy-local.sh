#!/bin/bash
# Deploy the freshly built Debug VoiceInk.app to /Applications.
# Personal Team can't use Archive -> Distribute, so we copy from DerivedData.
# Use --build to produce the local Debug build first, and --open to launch it.

set -euo pipefail

BUILD_FIRST=0
OPEN_AFTER_DEPLOY=0

usage() {
    echo "Usage: $0 [--build] [--open]"
    echo ""
    echo "  --build   Build Debug app with LocalBuild.xcconfig before deploying (Apple Development identity if present, else ad-hoc)"
    echo "  --open    Open /Applications/VoiceInk.app after deploying"
}

for arg in "$@"; do
    case "$arg" in
        --build)
            BUILD_FIRST=1
            ;;
        --open)
            OPEN_AFTER_DEPLOY=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            usage
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLED="/Applications/VoiceInk.app"

# Xcode's default DerivedData folder for this checkout (the one Cmd+R uses).
find_debug_app() {
    local dir
    for dir in "$HOME/Library/Developer/Xcode/DerivedData"/VoiceInk-*; do
        [ -f "$dir/info.plist" ] || continue
        if [ "$(/usr/libexec/PlistBuddy -c 'Print :WorkspacePath' "$dir/info.plist" 2>/dev/null)" = "$REPO_ROOT/VoiceInk.xcodeproj" ]; then
            echo "$dir/Build/Products/Debug/VoiceInk.app"
            return
        fi
    done
}

# Prefer a real Apple Development identity over ad-hoc signing. Ad-hoc
# signatures are keyed by per-build cdhash, so every rebuild re-triggers the
# login-keychain "allow access" prompt for each stored API key. A stable
# signing identity gives a stable designated requirement, so "Always Allow"
# survives rebuilds. Falls back to ad-hoc when no identity is installed.
# Mirrors upstream's `make local`: pass the identity's SHA-1 hash and require
# signing. The identity goes through a wrapper xcconfig because on Xcode 26 the
# CODE_SIGN_IDENTITY=- line in LocalBuild.xcconfig beats a command-line override
# (verified with -showBuildSettings) and the app silently ends up ad-hoc signed.
SIGN_IDENTITY="${LOCAL_CODESIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development: / { print $2; exit }')
fi
if [ -n "$SIGN_IDENTITY" ]; then
    SIGN_REQUIRED=YES
    echo "Using stable local signing identity: $SIGN_IDENTITY"
else
    SIGN_IDENTITY="-"
    SIGN_REQUIRED=NO
    echo "No Apple Development identity found; using ad-hoc signing (keychain prompts will recur after rebuilds)"
fi

SIGN_XCCONFIG="$(mktemp -t voiceink-sign).xcconfig"
trap 'rm -f "$SIGN_XCCONFIG"' EXIT
printf '#include "%s/LocalBuild.xcconfig"\nCODE_SIGN_IDENTITY = %s\n' "$REPO_ROOT" "$SIGN_IDENTITY" > "$SIGN_XCCONFIG"

if [ "$BUILD_FIRST" -eq 1 ]; then
    echo "Building Debug VoiceInk.app..."
    xcodebuild -quiet \
        -skipPackagePluginValidation \
        -skipMacroValidation \
        -project "$REPO_ROOT/VoiceInk.xcodeproj" \
        -scheme VoiceInk \
        -configuration Debug \
        -xcconfig "$SIGN_XCCONFIG" \
        CODE_SIGNING_REQUIRED="$SIGN_REQUIRED" \
        CODE_SIGNING_ALLOWED=YES \
        DEVELOPMENT_TEAM="" \
        CODE_SIGN_ENTITLEMENTS="$REPO_ROOT/VoiceInk/VoiceInk.local.entitlements" \
        SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCAL_BUILD' \
        build
    DERIVED_DATA="$(find_debug_app)"
else
    # Refuse to install a product older than the Swift sources (builds from
    # worktrees or other checkouts write elsewhere).
    DERIVED_DATA="$(find_debug_app)"
    if [ -n "$DERIVED_DATA" ] && [ -d "$DERIVED_DATA" ]; then
        STALE_CHECK=$(find "$REPO_ROOT/VoiceInk" -name "*.swift" -newer "$DERIVED_DATA/Contents/MacOS/VoiceInk" -print -quit 2>/dev/null)
        if [ -n "$STALE_CHECK" ]; then
            echo "❌ Built app is OLDER than source (e.g. $STALE_CHECK)."
            echo "   Run: $0 --build --open"
            exit 1
        fi
    fi
fi

if [ -z "$DERIVED_DATA" ] || [ ! -d "$DERIVED_DATA" ]; then
    echo "❌ No Debug build of this checkout found in Xcode's DerivedData"
    echo "   Build it in Xcode first (Cmd+R), or run: $0 --build"
    exit 1
fi

if pgrep -x VoiceInk >/dev/null; then
    echo "❌ VoiceInk is currently running. Quit it first (Cmd+Q or Xcode stop button)."
    exit 1
fi

if [ -d "$INSTALLED" ]; then
    TRASH_NAME="VoiceInk-old-$(date +%Y%m%d-%H%M%S).app"
    echo "📦 Moving old /Applications/VoiceInk.app to Trash as $TRASH_NAME"
    mv "$INSTALLED" "$HOME/.Trash/$TRASH_NAME"
fi

echo "📋 Copying new build to /Applications/VoiceInk.app"
cp -R "$DERIVED_DATA" "$INSTALLED"

VERSION=$(defaults read "$INSTALLED/Contents/Info.plist" CFBundleShortVersionString)
BUNDLE_ID=$(defaults read "$INSTALLED/Contents/Info.plist" CFBundleIdentifier)

echo ""
echo "✅ Deployed VoiceInk $VERSION ($BUNDLE_ID)"
echo ""

if [ "$OPEN_AFTER_DEPLOY" -eq 1 ]; then
    echo "Opening /Applications/VoiceInk.app"
    open "$INSTALLED"
    echo ""
fi

echo "Next steps:"
echo "  1. Launch from /Applications (Spotlight: \"VoiceInk\")"
echo "  2. Dictate once in each Mode you use"
echo "  3. If keychain prompts appear, check: codesign -dr - /Applications/VoiceInk.app"
echo "  4. Confirm Settings → \"Automatically Check for Updates\" is off (LOCAL_BUILD enforces it)"
echo "  5. Re-grant Accessibility permission if macOS re-asks"
