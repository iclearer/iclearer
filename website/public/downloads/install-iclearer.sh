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

# Eject leftover installer volumes so a new attach never becomes "Install iClearer 1".
for vol in /Volumes/Install\ iClearer*; do
  [[ -d "$vol" ]] || continue
  echo "Ejecting leftover $vol"
  hdiutil detach "$vol" >/dev/null 2>&1 || diskutil eject "$vol" >/dev/null 2>&1 || true
done

# Newest by modification time (Safari names duplicates "iClearer (4).dmg", etc.).
# Walk newest → oldest and skip tiny/incomplete downloads.
SRC=""
while IFS= read -r candidate; do
  [[ -f "$candidate" ]] || continue
  size="$(stat -f%z "$candidate" 2>/dev/null || echo 0)"
  # Real DMG is ~1–2 MB; skip truncated downloads under 500 KB.
  if [[ "$size" -ge 500000 ]]; then
    SRC="$candidate"
    break
  fi
  echo "Skipping incomplete download: $candidate (${size} bytes)"
done < <(ls -t "$HOME"/Downloads/iClearer*.dmg 2>/dev/null || true)

if [[ -n "${SRC:-}" && -f "$SRC" ]]; then
  echo "Using newest DMG: $SRC"
else
  echo "Downloading iClearer…"
  curl -fL --progress-bar -o "$WORK/iClearer.dmg" "$DMG_URL"
  SRC="$WORK/iClearer.dmg"
fi

mkdir -p "$MOUNT"
# Private mountpoint avoids /Volumes/Install iClearer vs "Install iClearer 1" races.
hdiutil attach "$SRC" -nobrowse -quiet -mountpoint "$MOUNT"

if [[ ! -d "$MOUNT/iClearer.app" ]]; then
  echo "iClearer.app was not found in the disk image." >&2
  exit 1
fi

BIN="$MOUNT/iClearer.app/Contents/MacOS/iClearer"
if [[ ! -f "$BIN" ]]; then
  echo "iClearer binary was not found in the disk image." >&2
  exit 1
fi

ARCHS="$(lipo -archs "$BIN" 2>/dev/null || true)"
echo "DMG architectures: ${ARCHS:-unknown}"
case "$CHIP" in
  arm64)
    if ! printf '%s' "$ARCHS" | grep -qw arm64; then
      echo "This DMG is not built for Apple Silicon ($ARCHS)." >&2
      exit 1
    fi
    ;;
  x86_64)
    if ! printf '%s' "$ARCHS" | grep -Eqw 'x86_64|i386'; then
      echo "This DMG is not built for Intel Macs ($ARCHS)." >&2
      echo "Delete old downloads and get the latest from https://iclearer.com/#install" >&2
      exit 1
    fi
    ;;
esac

echo "Installing to $APP_DEST"
rm -rf "$APP_DEST"
# ditto preserves Mac app metadata better than cp -R on Intel.
ditto "$MOUNT/iClearer.app" "$APP_DEST"
xattr -cr "$APP_DEST" 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

INST_BIN="$APP_DEST/Contents/MacOS/iClearer"
INST_ARCHS="$(lipo -archs "$INST_BIN" 2>/dev/null || true)"
echo "Installed architectures: ${INST_ARCHS:-missing}"
if [[ "$CHIP" == "x86_64" ]] && ! printf '%s' "$INST_ARCHS" | grep -Eqw 'x86_64|i386'; then
  echo "Install failed: /Applications/iClearer.app has no Intel binary." >&2
  exit 1
fi

# Detach before open so LaunchServices sees the installed copy, not the volume.
hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
sleep 0.5

# Refresh Launch Services, then open the installed app (not a stale volume copy).
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DEST" >/dev/null 2>&1 || true
open "$APP_DEST" || {
  echo "open failed — trying direct launch…" >&2
  "$INST_BIN" &
}
echo "iClearer is installed. You can delete the DMG in Downloads."
