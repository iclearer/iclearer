#!/usr/bin/env python3
"""Write a simple Clearaer app icon as an iconset."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


def png(width: int, height: int, pixels: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b""
    stride = width * 4
    for y in range(height):
        raw += b"\x00" + pixels[y * stride : (y + 1) * stride]
    return b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(raw, 9)),
            chunk(b"IEND", b""),
        ]
    )


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def draw(size: int) -> bytes:
    pixels = bytearray(size * size * 4)
    cx = cy = size / 2
    radius = size * 0.46

    for y in range(size):
        for x in range(size):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            dist = (dx * dx + dy * dy) ** 0.5
            i = (y * size + x) * 4
            if dist > radius + 1:
                pixels[i : i + 4] = b"\x00\x00\x00\x00"
                continue

            edge = max(0.0, min(1.0, radius + 1 - dist))
            t = (y / size) * 0.7 + 0.15
            r = lerp(20, 46, t)
            g = lerp(110, 168, t)
            b = lerp(92, 132, t)

            # breeze mark
            nx = dx / radius
            ny = dy / radius
            breeze = abs(ny + 0.18 * (nx**3) * 4) < 0.11 and abs(nx) < 0.62
            breeze2 = abs(ny - 0.22 + 0.12 * (nx**2) * 3) < 0.08 and abs(nx) < 0.48
            if breeze or breeze2:
                r, g, b = 246, 248, 244

            pixels[i] = r
            pixels[i + 1] = g
            pixels[i + 2] = b
            pixels[i + 3] = int(255 * edge)
    return bytes(pixels)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    iconset = out / "AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    specs = {
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
    for name, size in specs.items():
        (iconset / name).write_bytes(png(size, size, draw(size)))
    print(iconset)


if __name__ == "__main__":
    main()
