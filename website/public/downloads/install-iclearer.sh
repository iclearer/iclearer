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

# Newest local download wins — Safari names duplicates "iClearer (2).dmg", etc.
SRC="$(ls -t "$HOME"/Downloads/iClearer*.dmg 2>/dev/null | head -1 || true)"
if [[ -n "${SRC:-}" && -f "$SRC" ]]; then
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

BIN="$MOUNT/iClearer.app/Contents/MacOS/iClearer"
if [[ -f "$BIN" ]]; then
  ARCHS="$(lipo -archs "$BIN" 2>/dev/null || true)"
  if [[ -n "$ARCHS" ]]; then
    case "$CHIP" in
      arm64)
        if ! printf '%s' "$ARCHS" | grep -qw arm64; then
          echo "This DMG is not built for Apple Silicon ($ARCHS)." >&2
          exit 1
        fi
        ;;
      x86_64)
        if ! printf '%s' "$ARCHS" | grep -Eqw 'x86_64|i386'; then
          echo "This DMG is not built for Intel Macs ($ARCHS). Download the latest iClearer.dmg from iclearer.com." >&2
          exit 1
        fi
        ;;
    esac
  fi
fi

echo "Installing to $APP_DEST"
rm -rf "$APP_DEST"
cp -R "$MOUNT/iClearer.app" "$APP_DEST"
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

# Detach before open so LaunchServices sees the installed copy, not the volume.
hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
sleep 0.4
open "$APP_DEST"
echo "iClearer is installed. You can delete the DMG in Downloads."
