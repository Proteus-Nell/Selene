#!/usr/bin/env python3
"""Regenerates the launcher icon from app/android/logo-source.png (AND-38).

The icon is generated rather than hand-exported so that it can be rebuilt when
the palette moves or a density is added, and so that the thing in version
control is the artwork plus the rule for placing it, not sixteen opaque PNGs
somebody would have to redraw.

Two layers, per Android's adaptive icon:

  * the background is a colour resource, so values-night can restate it;
  * the foreground is this artwork, emitted white-on-transparent and **tinted**
    at render time by @color/ic_launcher_ink. The source art is uniformly
    near-black, so only its alpha channel carries any information -- which is
    what makes a single bitmap serve both themes. Baking the colour in would
    need two sets of PNGs and would put a black mark on a near-black tile in
    dark mode, where it would disappear.

The mark sits at ART_DP of the 108dp canvas rather than filling the 72dp safe
zone. The artwork is itself a circle, and at 72 its outer ring lands exactly on
the mask boundary, where a round launcher's antialiasing eats it. At 64 there is
a visible ring of background inside every mask shape and the inset reads as
deliberate.

Usage:  python3 tools/scripts/gen_launcher_icon.py
Needs:  Pillow.
"""

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - a developer-machine script
    sys.exit('Pillow is required: pip install Pillow')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'app', 'android', 'logo-source.png')
RES = os.path.join(ROOT, 'app', 'android', 'app', 'src', 'main', 'res')

# Light-theme values only. The adaptive icon is tinted from colour resources, so
# these are used solely for the flattened pre-API-26 icons, which have no
# background layer and no way to follow the system theme.
LIGHT_BG = (0xE4, 0xEB, 0xDF)   # AppColors.lightSurfaceContainer
LIGHT_INK = (0x22, 0x26, 0x1F)  # AppColors.lightOnSurface

CANVAS_DP = 108   # the adaptive canvas
ART_DP = 64       # the mark, inside the 72dp safe zone with room to spare
# minSdk is 26, which is the release adaptive icons arrived in, so every
# supported device resolves mipmap-anydpi-v26/ic_launcher.xml and never these.
# They are kept because a handful of third-party launchers and share surfaces
# still ask for a plain drawable, and because 12KB is not worth the argument.
LEGACY_DP = 48
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def _shape(art, box):
    """The artwork's alpha, scaled to fit a `box` square and centred in it."""
    width, height = art.size
    scale = box / max(width, height)
    resized = art.resize(
        (max(1, round(width * scale)), max(1, round(height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new('L', (box, box), 0)
    canvas.paste(resized, ((box - resized.width) // 2, (box - resized.height) // 2))
    return canvas


def _foreground(art, canvas_px, art_px):
    """White-on-transparent tile for the adaptive foreground, tinted at runtime."""
    alpha = Image.new('L', (canvas_px, canvas_px), 0)
    alpha.paste(_shape(art, art_px), ((canvas_px - art_px) // 2,) * 2)
    out = Image.new('RGBA', (canvas_px, canvas_px), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def _legacy(art, px):
    """Flattened icon for launchers with no adaptive-icon support."""
    inner = round(px * ART_DP / CANVAS_DP * (CANVAS_DP / LEGACY_DP))
    tile = Image.new('RGBA', (px, px), LIGHT_BG + (255,))
    layer = Image.new('RGBA', (px, px), LIGHT_INK + (0,))
    alpha = Image.new('L', (px, px), 0)
    alpha.paste(_shape(art, inner), ((px - inner) // 2,) * 2)
    layer.putalpha(alpha)
    return Image.alpha_composite(tile, layer)


def main():
    source = Image.open(SRC).convert('RGBA')
    alpha = source.getchannel('A')
    box = alpha.getbbox()
    if box is None:
        sys.exit(f'{SRC} is fully transparent')
    # Cropped to its own ink, so the mark is optically centred rather than
    # centred on whatever padding the export happened to carry.
    art = alpha.crop(box)

    written = 0
    for name, scale in DENSITIES.items():
        directory = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(directory, exist_ok=True)
        _foreground(art, round(CANVAS_DP * scale), round(ART_DP * scale)).save(
            os.path.join(directory, 'ic_launcher_logo.png')
        )
        _legacy(art, round(LEGACY_DP * scale)).save(
            os.path.join(directory, 'ic_launcher.png')
        )
        written += 2
    print(f'wrote {written} files from {os.path.relpath(SRC, ROOT)}')


if __name__ == '__main__':
    main()
