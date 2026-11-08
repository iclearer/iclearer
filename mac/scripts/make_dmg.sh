#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/iClearer.app"
DMG="$ROOT/iClearer.dmg"
STAGE="$ROOT/.dmg-stage"

if [[ ! -d "$APP" ]]; then
  echo "Build the app first: ./build.sh" >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/iClearer.app"
ln -s /Applications "$STAGE/Applications"

if [[ -f "$ROOT/scripts/Open iClearer.command" ]]; then
  cp "$ROOT/scripts/Open iClearer.command" "$STAGE/Open iClearer.command"
  chmod +x "$STAGE/Open iClearer.command"
elif [[ -f "$ROOT/scripts/Open Clearaer.command" ]]; then
  cp "$ROOT/scripts/Open Clearaer.command" "$STAGE/Open iClearer.command"
  chmod +x "$STAGE/Open iClearer.command"
fi

cat > "$STAGE/Install iClearer.txt" <<'EOF'
Install iClearer
================
1. Drag iClearer into the Applications folder.
2. Apple will warn you the first time. That is normal.
   Do not click Move to Trash.

Easiest:
  Right-click iClearer → Open → Open.

If you already saw “iClearer Not Opened”:
  Click Done.
  Open System Settings → Privacy & Security.
  Scroll down and click Open Anyway.

Terminal:
  xattr -dr com.apple.quarantine /Applications/iClearer.app
EOF

echo "Creating installer disk image…"
hdiutil create \
  -volname "Install iClearer" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG" >/dev/null

rm -rf "$STAGE"
echo "Created $DMG"
ls -lh "$DMG"
