#!/bin/bash
# Install iClearer from the DMG and clear the macOS download warning.
# Usage:
#   bash install-iclearer.sh
#   curl -fsSL https://iclearer.com/downloads/install-iclearer.sh | bash
set -euo pipefail

DMG_URL="${ICLEARER_DMG_URL:-https://iclearer.com/downloads/iClearer.dmg}"
APP_DEST="/Applications/iClearer.app"
WORK="$(mktemp -d /tmp/iclearer-install.XXXXXX)"
MOUNT="$WORK/mnt"
cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iClearer is a Mac app." >&2
  exit 1
fi

CHIP="$(uname -m)"
if [[ "$CHIP" == "arm64" ]]; then
  echo "Installing iClearer for Apple Silicon."
elif [[ "$CHIP" == "x86_64" ]]; then
  echo "Installing iClearer for Intel."
else
  echo "Installing iClearer ($CHIP)."
fi

SRC=""
if [[ -f "$HOME/Downloads/iClearer.dmg" ]]; then
  SRC="$HOME/Downloads/iClearer.dmg"
  echo "Using $SRC"
else
  echo "Downloading iClearer…"
  curl -fL --progress-bar -o "$WORK/iClearer.dmg" "$DMG_URL"
  SRC="$WORK/iClearer.dmg"
fi

mkdir -p "$MOUNT"
hdiutil attach "$SRC" -nobrowse -quiet -mountpoint "$MOUNT"

if [[ ! -d "$MOUNT/iClearer.app" ]]; then
  echo "iClearer.app was not found in the disk image." >&2
  exit 1
fi

echo "Installing to $APP_DEST"
rm -rf "$APP_DEST"
cp -R "$MOUNT/iClearer.app" "$APP_DEST"
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
open "$APP_DEST"
echo "iClearer is installed. You can delete the DMG in Downloads."
