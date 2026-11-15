# Brand assets

The app icon is pixel art of a hand flipping a penny. Its master is the 32 x 32 sprite in `tools/brand/penny_icon.py`, in Penny's token colours. Do not edit these PNGs by hand: change the sprite and run `task gen:icons`, which rewrites them and regenerates every platform icon.

| File | Use |
| --- | --- |
| `app-icon-32.png` | Native size. Drawn in the app at whole-number scales with `PennyPixelArt` (sign-in, splash, empty states) |
| `app-icon-1024.png` | Source for the iOS, macOS, Windows, web and legacy Android icons (each cell 32 px) |
| `app-icon-foreground-432.png` | Android adaptive-icon foreground: the art centred on a 54-cell canvas, so it stays inside the safe zone |

Pixel art appears only at brand moments; the working UI is vector.
