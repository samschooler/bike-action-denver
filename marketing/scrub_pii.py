#!/usr/bin/env python3
"""
Obscures PII regions (plates, addresses, case numbers) in the raw app-frame
screenshots before compose.py runs. Writes scrubbed copies in-place so the
public repo never ships real user data.

Usage:
    python3 marketing/scrub_pii.py

Coord system is the raw 1179×2556 iPhone 15 source-screenshot space.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
FRAMES = os.path.join(ROOT, "app-frames")

# Pixelation boxes (real PII → blurred blocks).
PIXELATE = {
    "03.png": [
        (470, 430, 720, 520),     # car plate in photo
        (140, 1310, 780, 1380),   # "2728 W 13th Ave"
        (140, 1410, 740, 1490),   # "Denver, CO 80204-2316 ±4m"
        (80,  1540, 400, 1800),   # plate thumbnail in Plate row
        (380, 1620, 1050, 1720),  # "8415329 · Colorado" (widened to catch "8")
    ],
    "05.png": [],
}

# Solid-fill boxes (rewrites the area with a neutral color). Used when
# pixelation looks too busy — e.g. a long repeating column of case numbers.
# The fill color is the iOS secondary-label gray on a light background so
# it reads like "data placeholder" rather than "censored."
FILL_COLOR = (235, 235, 230)
FILL = {
    "03.png": [],
    # Block the date + case-number text block on each of the 7 history rows.
    # Rows span the full height of the list; each row ≈ 280 tall starting at
    # y≈615. We nuke the column x=280..760 (where date + case sit).
    "05.png": [
        (280, 615,  760, 785),    # row 1
        (280, 795,  760, 965),    # row 2
        (280, 975,  760, 1145),   # row 3
        (280, 1155, 760, 1325),   # row 4
        (280, 1335, 760, 1505),   # row 5
        (280, 1515, 760, 1685),   # row 6
        (280, 1695, 760, 1865),   # row 7
    ],
}


def pixelate_region(img: Image.Image, box, block: int = 24):
    x0, y0, x1, y1 = box
    if x1 <= x0 or y1 <= y0:
        return
    region = img.crop(box)
    w, h = region.size
    small = region.resize((max(1, w // block), max(1, h // block)), Image.NEAREST)
    region = small.resize((w, h), Image.NEAREST)
    img.paste(region, (x0, y0))


def fill_region(img: Image.Image, box, color=FILL_COLOR):
    x0, y0, x1, y1 = box
    if x1 <= x0 or y1 <= y0:
        return
    img.paste(Image.new("RGB", (x1 - x0, y1 - y0), color), (x0, y0))


def scrub(path: str):
    name = os.path.basename(path)
    img = Image.open(path).convert("RGB")
    px = PIXELATE.get(name, [])
    fl = FILL.get(name, [])
    for box in px:
        pixelate_region(img, box)
    for box in fl:
        fill_region(img, box)
    img.save(path, "PNG", optimize=True)
    print(f"scrubbed {name}: {len(px)} pixelate + {len(fl)} fill")


def main():
    for name in set(PIXELATE) | set(FILL):
        p = os.path.join(FRAMES, name)
        if os.path.exists(p):
            scrub(p)


if __name__ == "__main__":
    main()
