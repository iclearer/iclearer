#!/usr/bin/env python3
"""Build AppIcon.iconset from the glass-light brand mark (same asset as email).

Keep transparent corners so Dock/Finder show the clean glass squircle —
matching Apple Silicon — instead of a hard white plate.
Prefer official pre-rendered sizes when present for sharper dock icons.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image


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

# Prefer brand-pack rasters that already look clean at these pixel sizes.
PREFERRED = {
    64: "icon-glass-light-64.png",
    120: "icon-glass-light-120.png",
    180: "icon-glass-light-180.png",
    256: "icon-glass-light-256.png",
    512: "icon-glass-light-512.png",
    1024: "icon-glass-light-1024.png",
}


def asset_dirs(root: Path) -> list[Path]:
    return [
        root.parent / "website" / "public" / "assets" / "png",
        root.parent / "iClearer-developer-handoff" / "brand" / "logo-pack" / "png",
        root / "Resources",
    ]


def find_master(root: Path) -> Path:
    for folder in asset_dirs(root):
        path = folder / "icon-glass-light-1024.png"
        if path.is_file():
            return path
    fallback = root / "Resources" / "iclearer-icon-glass-light.png"
    if fallback.is_file():
        return fallback
    raise SystemExit("glass-light icon PNG not found")


def find_preferred(root: Path, size: int) -> Path | None:
    name = PREFERRED.get(size)
    if not name:
        return None
    for folder in asset_dirs(root):
        path = folder / name
        if path.is_file():
            return path
    return None


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def resize_hq(img: Image.Image, size: int) -> Image.Image:
    if img.size == (size, size):
        return img
    # Multi-step downsample keeps the glossy “i” smoother than a single jump.
    cur = img
    while cur.size[0] > size * 2:
        nxt = (cur.size[0] // 2, cur.size[1] // 2)
        cur = cur.resize(nxt, Image.Resampling.LANCZOS)
    return cur.resize((size, size), Image.Resampling.LANCZOS)


def render_size(root: Path, master: Image.Image, size: int) -> Image.Image:
    preferred = find_preferred(root, size)
    if preferred is not None:
        img = load_rgba(preferred)
        if img.size == (size, size):
            return img
        return resize_hq(img, size)
    # Nearest larger preferred source, else master 1024.
    for candidate in sorted((s for s in PREFERRED if s >= size)):
        path = find_preferred(root, candidate)
        if path is not None:
            return resize_hq(load_rgba(path), size)
    return resize_hq(master, size)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    root = Path(__file__).resolve().parents[1]
    master_path = find_master(root)
    master = load_rgba(master_path)

    iconset = out / "AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True, exist_ok=True)

    for name, size in SPECS.items():
        render_size(root, master, size).save(iconset / name, format="PNG")
    print(iconset)


if __name__ == "__main__":
    main()
