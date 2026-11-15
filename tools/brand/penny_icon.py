#!/usr/bin/env python3
"""Renders Penny's pixel-art app icon: a hand flipping a penny.

The sprite below is the master, on its native 32 x 32 grid. Edit it here and
run `task gen:icons`, which writes the PNGs to apps/client/assets/brand/ and
then generates every platform icon with flutter_launcher_icons.

Scaling is by whole numbers with nearest-neighbour sampling only, so the
pixel edges stay crisp (docs/architecture.md, "App icon"). Standard library
only: no image library to install.

Usage: python3 tools/brand/penny_icon.py [output-dir]
"""

import struct
import sys
import zlib
from pathlib import Path

# Colours are Penny's tokens (docs/design/tokens.json), so the icon belongs
# to the same palette as the app.
PALETTE = {
    ".": None,                     # transparent (rounded corners)
    "B": (0x1C, 0x2B, 0x3A),       # ink
    "C": (0x9C, 0x44, 0x20),       # copper-text: the coin's rim
    "c": (0xB4, 0x53, 0x2A),       # copper: the coin
    "h": (0xE0, 0x7A, 0x4A),       # copper (dark theme): the coin's lit side
    "w": (0xF8, 0xEA, 0xE2),       # copper-subtle: glint and motion marks
    "H": (0xE6, 0xEB, 0xF1),       # ink-subtle: the hand
    "s": (0xC3, 0xCC, 0xD7),       # ink-subtle-edge: the hand's shade
    "k": (0x84, 0x8D, 0x9A),       # border-control: the hand's outline
}

# 32 columns by 32 rows. B is the ink tile behind the art.
SPRITE = """
..BBBBBBBBBBBBBBBBBBBBBBBBBBBB..
.BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBCCCCCBBBBBBBB
BBBBBBBBBBBBBBBBBBChhcccCBBBBBBB
BBBBBBBBBBBBBBBBBChwhccccCBBBBBB
BBBBBBBBBBBBBBBBBChhcccccCBBBBBB
BBBBBBBBBBBBBBBBBCccccccCCBBBBBB
BBBBBBBBBBBBBBBBBCcccccccCBBBBBB
BBBBBBBBBBBBBBBBBBCccccCCBBBBBBB
BBBBBBBBBBBBBwBBBBBCCCCCBBBwBBBB
BBBBBBBBBBBBBwBBBBBBBBBBBBBwBBBB
BBBBBBBBBBBBBBwBBBBBBBBBBBwBBBBB
BBBBBBBBBBBBBBBBBBBkkBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBkHHkBBBBBBBBBB
BBBBBBBBBBBBBBBBBkHHskBBBBBBBBBB
BBBBBBBBBBBBBBBBkHHskBBBBBBBBBBB
BBBBBBBBBBBBBBBkHHskBBBBBBBBBBBB
BBBBBBBBBkkkkkkHHskBBBBBBBBBBBBB
BBBBBBBBkHHHHHHHHHkkkBBBBBBBBBBB
BBBBBBBBkHHHHHHHHHHHHkBBBBBBBBBB
BBBBBBBBkHHHHHHHkkkkHkBBBBBBBBBB
BBBBBBBBkHHHHHHHHHHHskBBBBBBBBBB
BBBBBBBBkHHHHHHHkkkkHkBBBBBBBBBB
BBBBBBBBkHHHHHHHHHHHskBBBBBBBBBB
BBBBBBBkkHHHHHHHkkkkHkBBBBBBBBBB
BBBBBBkHHHHHHHHHHHHHskBBBBBBBBBB
BBBBBkHHHsHHHHHHHHHskBBBBBBBBBBB
BBBBkHHHsskssssssskkBBBBBBBBBBBB
BBBkHHHskBBkkkkkkkBBBBBBBBBBBBBB
.BBkHHskBBBBBBBBBBBBBBBBBBBBBBB.
..BkHskBBBBBBBBBBBBBBBBBBBBBBB..
"""

GRID = 32


def parse(sprite: str) -> list[str]:
    rows = [r for r in sprite.strip("\n").split("\n")]
    if len(rows) != GRID or any(len(r) != GRID for r in rows):
        sizes = [len(r) for r in rows]
        raise SystemExit(f"sprite must be {GRID}x{GRID}; got {len(rows)} rows of widths {sizes}")
    unknown = {ch for r in rows for ch in r} - PALETTE.keys()
    if unknown:
        raise SystemExit(f"sprite uses colours not in PALETTE: {sorted(unknown)}")
    return rows


def write_png(path: Path, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    """Writes 8-bit RGBA pixels as a PNG."""
    height, width = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *px) for px in row) for row in pixels)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def render(rows: list[str], scale: int, canvas: int, opaque: bool) -> list[list[tuple[int, int, int, int]]]:
    """The sprite centred on a canvas of `canvas` grid cells, each cell
    `scale` pixels. `opaque` fills transparent cells with ink, for platforms
    that reject transparency (iOS)."""
    ink = PALETTE["B"]
    pad = (canvas - GRID) // 2
    out = []
    for y in range(canvas * scale):
        gy = y // scale - pad
        row = []
        for x in range(canvas * scale):
            gx = x // scale - pad
            colour = PALETTE[rows[gy][gx]] if 0 <= gx < GRID and 0 <= gy < GRID else None
            if colour is None:
                row.append((*ink, 255) if opaque else (0, 0, 0, 0))
            else:
                row.append((*colour, 255))
        out.append(row)
    return out


def main() -> None:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "apps/client/assets/brand")
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = parse(SPRITE)

    outputs = {
        # The master at native size, for in-app brand moments (sign-in).
        "app-icon-32.png": render(rows, 1, GRID, opaque=False),
        # The source for every platform icon: 32 x 32 cells of 32 px.
        "app-icon-1024.png": render(rows, 32, GRID, opaque=True),
        # Android adaptive foreground: the art on a 54-cell canvas, so the
        # hand and coin sit inside the 66 dp safe zone of the 108 dp icon.
        # 54 cells of 8 px = 432 px, the xxxhdpi foreground size.
        "app-icon-foreground-432.png": render(rows, 8, 54, opaque=False),
    }
    for name, pixels in outputs.items():
        write_png(out_dir / name, pixels)
        print(f"wrote {out_dir / name}")


if __name__ == "__main__":
    main()
