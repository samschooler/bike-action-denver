#!/usr/bin/env python3
"""
Composite a real iPhone simulator screenshot into one of the App Store
screenshot templates. The template has a rounded phone-shaped "slot" in
the center; this script masks + pastes the captured screenshot into it.

Usage:
    python3 marketing/compose.py <screen_number>     # 1..5

Expects:
    marketing/screenshots/<NN>-<slug>.png            # the template
    marketing/app-frames/<NN>.png                    # simulator screenshot

Writes:
    marketing/final/<NN>-<slug>.png                  # finished App Store-ready image
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
TEMPLATES = os.path.join(ROOT, "screenshots")
APP_FRAMES = os.path.join(ROOT, "app-frames")
FINAL = os.path.join(ROOT, "final")

W, H = 1320, 2868
PW = int(W * 0.66)
PH = int(PW * 2.164)
PX = (W - PW) // 2
PY = int(H * 0.36)
RADIUS = 72


def main(n: int):
    slug_map = {
        1: "01-hero.png", 2: "02-capture.png", 3: "03-detect.png",
        4: "04-submit.png", 5: "05-track.png",
    }
    if n not in slug_map:
        sys.exit(f"screen number must be 1..5, got {n}")
    template_path = os.path.join(TEMPLATES, slug_map[n])
    frame_path = os.path.join(APP_FRAMES, f"{n:02d}.png")
    out_path = os.path.join(FINAL, slug_map[n])

    if not os.path.exists(frame_path):
        sys.exit(f"missing {frame_path} — capture it with `xcrun simctl io booted screenshot` first")

    os.makedirs(FINAL, exist_ok=True)

    template = Image.open(template_path).convert("RGB")
    frame = Image.open(frame_path).convert("RGB")

    # Fit the screenshot to the phone slot (preserve aspect, crop excess).
    frame = frame.resize(_fit_crop_size(frame.size, (PW, PH)), Image.LANCZOS)
    frame = _crop_center(frame, (PW, PH))

    # Rounded-corner mask for the phone slot.
    mask = Image.new("L", (PW, PH), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, PW, PH], radius=RADIUS, fill=255)

    template.paste(frame, (PX, PY), mask)

    # Subtle outline around the phone slot, matching the placeholder.
    d = ImageDraw.Draw(template, "RGBA")
    d.rounded_rectangle([PX, PY, PX + PW, PY + PH], radius=RADIUS,
                        outline=(0, 0, 0, 40), width=3)

    template.save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path}  (mode={template.mode}, size={template.size})")


def _fit_crop_size(src, dst):
    sw, sh = src
    dw, dh = dst
    scale = max(dw / sw, dh / sh)
    return (int(sw * scale), int(sh * scale))


def _crop_center(img, dst):
    dw, dh = dst
    w, h = img.size
    left = (w - dw) // 2
    top = (h - dh) // 2
    return img.crop((left, top, left + dw, top + dh))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: compose.py <screen_number 1..5>")
    main(int(sys.argv[1]))
