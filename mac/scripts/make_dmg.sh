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
1. Download the DMG and drag iClearer into Applications.
2. The first time, right-click iClearer and choose Open.
   Do not click Move to Trash.
3. Or click Done, then System Settings → Privacy & Security → Open Anyway.

Or double-click “Open iClearer.command” in this window.

If the DMG is in Downloads (picks the newest, including "iClearer (4).dmg"):
  DMG=$(ls -t ~/Downloads/iClearer*.dmg 2>/dev/null | head -1)
  MNT=$(mktemp -d /tmp/iclearer-mnt.XXXXXX)
  hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MNT"
  rm -rf /Applications/iClearer.app
  ditto "$MNT/iClearer.app" /Applications/iClearer.app
  xattr -cr /Applications/iClearer.app
  hdiutil detach "$MNT"
  rmdir "$MNT" 2>/dev/null || true
  open /Applications/iClearer.app

If the app is already in Applications:
  xattr -dr com.apple.quarantine /Applications/iClearer.app && open /Applications/iClearer.app

One-line install:
  curl -fsSL https://iclearer.com/downloads/install-iclearer.sh | bash

More help: https://iclearer.com/#install
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
