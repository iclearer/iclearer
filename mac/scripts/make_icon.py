#!/usr/bin/env python3
"""Build AppIcon.iconset from the glass-light brand mark (same asset as email).

macOS applies its own squircle mask. Icons that are already rounded with
transparent corners pick up a dark fringe when that mask is applied twice.
We flatten the mark onto an opaque glass fill so the system mask is the
only rounder — matching the clean email logo look in Finder/Dock/DMG.
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


def find_source(root: Path) -> Path:
    candidates = [
        root.parent / "website" / "public" / "assets" / "png" / "icon-glass-light-1024.png",
        root / "Resources" / "iclearer-icon-glass-light.png",
        root.parent / "iClearer-developer-handoff" / "brand" / "logo-pack" / "png" / "icon-glass-light-1024.png",
    ]
    for path in candidates:
        if path.is_file():
            return path
    raise SystemExit("glass-light icon PNG not found")


def sample_fill(img: Image.Image) -> tuple[int, int, int, int]:
    """Pick an opaque glass fill near the mid-edge (not the letter)."""
    w, h = img.size
    for pt in [(w // 2, max(2, h // 12)), (max(2, w // 12), h // 2), (w // 2, h // 2)]:
        r, g, b, a = img.getpixel(pt)
        if a > 200:
            return (r, g, b, 255)
    return (236, 244, 250, 255)


def flatten_for_macos(src: Path, size: int) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    if img.size != (size, size):
        img = img.resize((size, size), Image.Resampling.LANCZOS)
    fill = sample_fill(img)
    base = Image.new("RGBA", (size, size), fill)
    # Composite logo; then force fully opaque so no fringe remains.
    base.alpha_composite(img)
    solid = Image.new("RGBA", (size, size))
    px = base.load()
    out = solid.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            if a < 255:
                fr, fg, fb, _ = fill
                # Blend toward fill, then store opaque.
                t = a / 255.0
                out[x, y] = (
                    int(r * t + fr * (1 - t)),
                    int(g * t + fg * (1 - t)),
                    int(b * t + fb * (1 - t)),
                    255,
                )
            else:
                out[x, y] = (r, g, b, 255)
    return solid


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    root = Path(__file__).resolve().parents[1]
    src = find_source(root)

    iconset = out / "AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True, exist_ok=True)

    # Build master 1024 flattened once, then resize.
    master = flatten_for_macos(src, 1024)
    master_path = iconset / "_master.png"
    master.save(master_path)

    for name, size in SPECS.items():
        dest = iconset / name
        if size == 1024:
            shutil.copy2(master_path, dest)
        else:
            resized = master.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(dest)
    master_path.unlink(missing_ok=True)
    print(iconset)


if __name__ == "__main__":
    main()
