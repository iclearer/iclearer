# iClearer Mac app

Native macOS cleaner (AppKit). Scans cache folders, shows sizes, moves selected items to Trash.

## Build

```bash
./build.sh
```

Needs macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

## Distribute

`dist/iClearer.dmg` is the installer image used by the website download button.

First launch on another Mac may need **right-click → Open** until the build is notarized (`scripts/notarize.sh`).
