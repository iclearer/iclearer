#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Clearaer.app"
DMG="$ROOT/Clearaer.dmg"
STAGE="$ROOT/.dmg-stage"
RW="$ROOT/.clearaer-rw.dmg"

if [[ ! -d "$APP" ]]; then
  echo "Build the app first: ./build.sh" >&2
  exit 1
fi

rm -rf "$STAGE" "$RW" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Clearaer.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/scripts/Open Clearaer.command" "$STAGE/Open Clearaer.command"
chmod +x "$STAGE/Open Clearaer.command"
cat > "$STAGE/Install Clearaer.txt" <<'EOF'
Install Clearaer
================
1. Drag Clearaer into the Applications folder.
2. Apple will warn you the first time. That is normal.
   Do not click Move to Trash.

Easiest:
  Right-click Clearaer → Open → Open.

If you already saw “Clearaer Not Opened”:
  Click Done.
  Open System Settings → Privacy & Security.
  Scroll down and click Open Anyway.

Or double-click “Open Clearaer.command” in this window.
  That copies the app to Applications and clears the warning.

Terminal:
  xattr -dr com.apple.quarantine /Applications/Clearaer.app
EOF

echo "Creating installer disk image…"
hdiutil create \
  -volname "Install Clearaer" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG" >/dev/null

rm -rf "$STAGE"
echo "Created $DMG"
ls -lh "$DMG"
