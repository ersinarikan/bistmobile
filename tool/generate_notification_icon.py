#!/usr/bin/env python3
"""Android FCM tray icon — white alpha silhouette (loupe + bars).

  python3 tool/generate_notification_icon.py

Manifest: com.google.firebase.messaging.default_notification_icon → @drawable/ic_stat_lotlot
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"

SIZES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}


def draw_stat(size: int) -> Image.Image:
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)

    cx = cy = s * 0.46
    outer_r = s * 0.32
    ring_w = s * 0.10
    inner_r = outer_r - ring_w

    ang = math.radians(48)
    hx = cx + math.cos(ang) * (outer_r - ring_w * 0.2)
    hy = cy + math.sin(ang) * (outer_r - ring_w * 0.2)
    hw = ring_w * 1.15
    hl = outer_r * 0.55
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    tip = (hx + ux * hl, hy + uy * hl)
    pts = [
        (hx - px * hw / 2, hy - py * hw / 2),
        (hx + px * hw / 2, hy + py * hw / 2),
        (tip[0] + px * hw / 2, tip[1] + py * hw / 2),
        (tip[0] - px * hw / 2, tip[1] - py * hw / 2),
    ]
    d.polygon(pts, fill=white)
    d.ellipse(
        [tip[0] - hw / 2, tip[1] - hw / 2, tip[0] + hw / 2, tip[1] + hw / 2],
        fill=white,
    )

    d.ellipse(
        [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r], fill=white
    )
    hole = Image.new("L", (s, s), 0)
    ImageDraw.Draw(hole).ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=255
    )
    r, g, b, a = img.split()
    a = Image.composite(Image.new("L", (s, s), 0), a, hole)
    img = Image.merge("RGBA", (r, g, b, a))
    d = ImageDraw.Draw(img)

    pad = inner_r * 0.28
    left = cx - inner_r + pad
    right = cx + inner_r - pad
    bottom = cy + inner_r - pad * 0.85
    top = cy - inner_r + pad * 1.1
    h = bottom - top
    bw = (right - left) / 5
    for i, hn in enumerate((0.35, 0.55, 0.78)):
        x0 = left + bw * (0.4 + i * 1.5)
        x1 = x0 + bw
        y0 = bottom - h * hn
        d.rounded_rectangle(
            [x0, y0, x1, bottom], radius=max(1, int(s * 0.02)), fill=white
        )

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    px_out = out.load()
    for y in range(size):
        for x in range(size):
            _, _, _, a = px_out[x, y]
            if a < 40:
                px_out[x, y] = (0, 0, 0, 0)
            else:
                px_out[x, y] = (255, 255, 255, 255 if a > 128 else a)
    return out


def main() -> None:
    xml = RES / "drawable" / "ic_stat_lotlot.xml"
    if xml.exists():
        xml.unlink()
    for folder, px in SIZES.items():
        dest_dir = RES / folder
        dest_dir.mkdir(parents=True, exist_ok=True)
        path = dest_dir / "ic_stat_lotlot.png"
        draw_stat(px).save(path, "PNG", optimize=True)
        print(f"Wrote {path}")


if __name__ == "__main__":
    main()
