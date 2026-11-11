#!/bin/zsh
# Installs iClearer to Applications and clears the macOS download warning.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DEST="/Applications/iClearer.app"
SOURCE=""

if [[ -d "$HERE/iClearer.app" ]]; then
  SOURCE="$HERE/iClearer.app"
elif [[ -d "/Applications/iClearer.app" ]]; then
  SOURCE="/Applications/iClearer.app"
else
  osascript -e 'display alert "iClearer not found" message "Keep this helper in the same Install iClearer window as the app, or drag iClearer to Applications first."'
  exit 1
fi

if [[ "$SOURCE" != "$APP_DEST" ]]; then
  rm -rf "$APP_DEST"
  cp -R "$SOURCE" "$APP_DEST"
fi

xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
open "$APP_DEST"
