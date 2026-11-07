#!/bin/bash
# Installs Clearaer to Applications and clears the macOS download warning.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SOURCE=""
if [ -d "$HERE/Clearaer.app" ]; then
  SOURCE="$HERE/Clearaer.app"
elif [ -d "/Applications/Clearaer.app" ]; then
  SOURCE="/Applications/Clearaer.app"
fi

if [ -z "$SOURCE" ]; then
  osascript -e 'display alert "Clearaer not found" message "Keep this helper in the same Install Clearaer window as the app, or drag Clearaer to Applications first."'
  exit 1
fi

if [ "$SOURCE" != "/Applications/Clearaer.app" ]; then
  rm -rf "/Applications/Clearaer.app"
  cp -R "$SOURCE" "/Applications/Clearaer.app"
fi

xattr -dr com.apple.quarantine "/Applications/Clearaer.app" 2>/dev/null || true
open "/Applications/Clearaer.app"
