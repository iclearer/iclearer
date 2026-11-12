#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/iClearer.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
MINOS="13.0"
WORK="$ROOT/.build"

rm -rf "$APP" "$WORK"
mkdir -p "$MACOS" "$RES" "$WORK"

echo "Generating app icon…"
python3 "$ROOT/scripts/make_icon.py" "$RES"

compile() {
  local arch="$1"
  echo "Compiling iClearer ($arch)…"
  swiftc \
    -O \
    -target "${arch}-apple-macosx${MINOS}" \
    -sdk "$SDK" \
    -o "$WORK/iClearer-${arch}" \
    "$ROOT"/Sources/*.swift
}

compile arm64
compile x86_64

echo "Creating universal binary (Intel + Apple Silicon)…"
lipo -create \
  -output "$MACOS/iClearer" \
  "$WORK/iClearer-arm64" \
  "$WORK/iClearer-x86_64"
lipo -info "$MACOS/iClearer"
rm -rf "$WORK"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Unlock modal / brand mark (glass light).
for f in iclearer-icon-glass-light.svg iclearer-icon-glass-light.png; do
  if [[ -f "$ROOT/Resources/$f" ]]; then
    cp "$ROOT/Resources/$f" "$RES/"
  elif [[ -f "$ROOT/../$f" ]]; then
    cp "$ROOT/../$f" "$RES/"
  fi
done
# Prefer the 1024 glass-light master for crisp Unlock / dock icons.
if [[ -f "$ROOT/../website/public/assets/png/icon-glass-light-1024.png" ]]; then
  cp "$ROOT/../website/public/assets/png/icon-glass-light-1024.png" "$RES/iclearer-icon-glass-light.png"
elif [[ ! -f "$RES/iclearer-icon-glass-light.png" && -f "$ROOT/../website/public/assets/png/icon-glass-light-180.png" ]]; then
  cp "$ROOT/../website/public/assets/png/icon-glass-light-180.png" "$RES/iclearer-icon-glass-light.png"
fi
if [[ ! -f "$RES/iclearer-icon-glass-light.svg" && -f "$ROOT/../iclearer-icon-glass-light.svg" ]]; then
  cp "$ROOT/../iclearer-icon-glass-light.svg" "$RES/iclearer-icon-glass-light.svg"
fi
echo -n "APPL????" > "$APP/Contents/PkgInfo"

if [[ -d "$RES/AppIcon.iconset" ]]; then
  iconutil -c icns "$RES/AppIcon.iconset" -o "$RES/AppIcon.icns"
  rm -rf "$RES/AppIcon.iconset"
fi

chmod +x "$MACOS/iClearer"
codesign --force --deep -s - "$APP" >/dev/null
echo "Built $APP"
"$ROOT/scripts/make_dmg.sh"
# Keep the website download in sync with this build.
WEBSITE_DMG="$ROOT/../website/public/downloads/iClearer.dmg"
mkdir -p "$(dirname "$WEBSITE_DMG")"
cp -f "$ROOT/iClearer.dmg" "$WEBSITE_DMG"
echo "Mirrored download: $WEBSITE_DMG"

echo "Open with:  open \"$APP\""
echo "Install image: $ROOT/iClearer.dmg"
