#!/bin/zsh
# Notarize Clearaer after you join the Apple Developer Program ($99/year).
# 1. Create a Developer ID Application certificate in Xcode or developer.apple.com
# 2. Create an app-specific password at appleid.apple.com
# 3. Store it once:
#      xcrun notarytool store-credentials "clearaer"
#         --apple-id "you@email.com"
#         --team-id "TEAMID"
#         --password "app-specific-password"
# 4. Run: ./scripts/notarize.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Clearaer.app"
DMG="$ROOT/Clearaer.dmg"
IDENTITY="${CLEARAER_SIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | awk -F'\"' '/Developer ID Application/ {print $2; exit}')"
fi

if [[ -z "$IDENTITY" ]]; then
  echo "No Developer ID Application certificate found."
  echo "Join https://developer.apple.com/programs/ then create a Developer ID Application cert."
  exit 1
fi

if [[ ! -d "$APP" ]]; then
  echo "Build first: ./build.sh"
  exit 1
fi

echo "Signing with $IDENTITY"
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --verbose "$APP"

"$ROOT/scripts/make_dmg.sh"
codesign --force --sign "$IDENTITY" "$DMG"

echo "Uploading to Apple notarization…"
xcrun notarytool submit "$DMG" --keychain-profile "clearaer" --wait
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo "Notarized. Copy $DMG to the MealLens public/downloads folder."
spctl -a -vv -t install "$DMG"
