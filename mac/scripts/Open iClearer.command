#!/bin/zsh
set -euo pipefail
APP="/Applications/iClearer.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/iClearer.app"
if [[ -d "$SRC" ]]; then
  rm -rf "$APP"
  cp -R "$SRC" "$APP"
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
open "$APP"
