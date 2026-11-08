#!/usr/bin/env python3
"""Build AppIcon.iconset from the glass-light brand mark."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


SPECS = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def find_source(root: Path) -> Path:
    candidates = [
        root / "Resources" / "iclearer-icon-glass-light.png",
        root.parent / "website" / "public" / "assets" / "png" / "icon-glass-light-1024.png",
        root.parent / "iClearer-developer-handoff" / "brand" / "logo-pack" / "png" / "icon-glass-light-1024.png",
    ]
    for path in candidates:
        if path.is_file():
            return path
    raise SystemExit("glass-light icon PNG not found")


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    root = Path(__file__).resolve().parents[1]
    src = find_source(root)
    # Prefer a 1024 master when available.
    master = root.parent / "website" / "public" / "assets" / "png" / "icon-glass-light-1024.png"
    if master.is_file():
        src = master

    iconset = out / "AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True, exist_ok=True)

    for name, size in SPECS.items():
        dest = iconset / name
        subprocess.run(
            ["sips", "-z", str(size), str(size), str(src), "--out", str(dest)],
            check=True,
            capture_output=True,
        )
    print(iconset)


if __name__ == "__main__":
    main()
