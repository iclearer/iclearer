#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/Clearaer.app"
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
  echo "Compiling Clearaer ($arch)…"
  swiftc \
    -O \
    -target "${arch}-apple-macosx${MINOS}" \
    -sdk "$SDK" \
    -o "$WORK/Clearaer-${arch}" \
    "$ROOT"/Sources/*.swift
}

compile arm64
compile x86_64

echo "Creating universal binary (Intel + Apple Silicon)…"
lipo -create \
  -output "$MACOS/Clearaer" \
  "$WORK/Clearaer-arm64" \
  "$WORK/Clearaer-x86_64"
lipo -info "$MACOS/Clearaer"
rm -rf "$WORK"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

if [[ -d "$RES/AppIcon.iconset" ]]; then
  iconutil -c icns "$RES/AppIcon.iconset" -o "$RES/AppIcon.icns"
  rm -rf "$RES/AppIcon.iconset"
fi

chmod +x "$MACOS/Clearaer"
codesign --force --deep -s - "$APP" >/dev/null
echo "Built $APP"
"$ROOT/scripts/make_dmg.sh"
echo "Open with:  open \"$APP\""
echo "Install image: $ROOT/Clearaer.dmg"
