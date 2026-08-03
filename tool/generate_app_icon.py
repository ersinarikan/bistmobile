#!/usr/bin/env python3
"""Regenerate crisp LOTLOT launcher icons (1024). Run from repo root:

  python3 tool/generate_app_icon.py
  dart run flutter_launcher_icons
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"

BG = (7, 22, 16, 255)  # #071610
ACCENT = (25, 227, 138, 255)  # #19e38a
ACCENT_FILL = (25, 227, 138, 210)
RING = (210, 218, 222, 255)
RING_DARK = (140, 150, 155, 255)
WHITE = (255, 255, 255, 255)
INNER_BG = (4, 12, 9, 255)


def draw_icon(size: int, transparent_bg: bool) -> Image.Image:
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0) if transparent_bg else BG)
    d = ImageDraw.Draw(img)

    cx = cy = s / 2
    outer_r = s * 0.30
    ring_w = s * 0.048
    inner_r = outer_r - ring_w

    bloom = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bloom)
    br = outer_r * 1.25
    bd.ellipse([cx - br, cy - br, cx + br, cy + br], fill=(*ACCENT[:3], 28))
    bloom = bloom.filter(ImageFilter.GaussianBlur(radius=s * 0.04))
    img = Image.alpha_composite(img, bloom)
    d = ImageDraw.Draw(img)

    ang = math.radians(48)
    hx = cx + math.cos(ang) * (outer_r - ring_w * 0.35)
    hy = cy + math.sin(ang) * (outer_r - ring_w * 0.35)
    hw = ring_w * 1.05
    hl = outer_r * 0.38
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    tip = (hx + ux * hl, hy + uy * hl)
    pts = [
        (hx - px * hw / 2, hy - py * hw / 2),
        (hx + px * hw / 2, hy + py * hw / 2),
        (tip[0] + px * hw / 2, tip[1] + py * hw / 2),
        (tip[0] - px * hw / 2, tip[1] - py * hw / 2),
    ]
    d.polygon(pts, fill=RING)
    d.ellipse(
        [tip[0] - hw / 2, tip[1] - hw / 2, tip[0] + hw / 2, tip[1] + hw / 2],
        fill=RING,
    )

    d.ellipse(
        [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r], fill=RING
    )
    mid_r = outer_r - ring_w * 0.45
    d.ellipse([cx - mid_r, cy - mid_r, cx + mid_r, cy + mid_r], fill=RING_DARK)
    d.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=INNER_BG
    )
    d.arc(
        [
            cx - outer_r + 4,
            cy - outer_r + 4,
            cx + outer_r - 4,
            cy + outer_r - 4,
        ],
        start=200,
        end=320,
        fill=(255, 255, 255, 180),
        width=max(3, int(ring_w * 0.35)),
    )

    chart = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chart)
    pad = inner_r * 0.26
    left, right = cx - inner_r + pad, cx + inner_r - pad
    top, bottom = cy - inner_r + pad * 1.15, cy + inner_r - pad * 0.9
    h = bottom - top
    w = right - left

    def P(xn: float, yn: float) -> tuple[float, float]:
        return (left + w * xn, bottom - h * yn)

    area = [
        P(0, 0),
        P(0, 0.12),
        P(0.14, 0.28),
        P(0.28, 0.18),
        P(0.42, 0.40),
        P(0.56, 0.32),
        P(0.70, 0.55),
        P(0.86, 0.48),
        P(1.0, 0.68),
        P(1.0, 0),
    ]
    cd.polygon(area, fill=ACCENT_FILL)

    line_pts = [
        P(0.02, 0.22),
        P(0.14, 0.38),
        P(0.28, 0.28),
        P(0.42, 0.52),
        P(0.56, 0.44),
        P(0.70, 0.68),
        P(0.86, 0.62),
    ]
    lw = max(8, int(s * 0.016))
    cd.line(line_pts, fill=WHITE, width=lw, joint="curve")
    rcap = lw / 2
    for p in (line_pts[0], line_pts[-1]):
        cd.ellipse(
            [p[0] - rcap, p[1] - rcap, p[0] + rcap, p[1] + rcap], fill=WHITE
        )

    ax, ay = line_pts[-1]
    al = s * 0.048
    arrow = [
        (ax + al * 0.55, ay - al * 0.85),
        (ax - al * 0.35, ay - al * 0.05),
        (ax + al * 0.15, ay + al * 0.40),
    ]
    cd.polygon(arrow, fill=ACCENT)

    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse(
        [
            cx - inner_r + 1,
            cy - inner_r + 1,
            cx + inner_r - 1,
            cy + inner_r - 1,
        ],
        fill=255,
    )
    img.paste(chart, (0, 0), mask)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    draw_icon(1024, False).save(OUT / "app_icon.png", "PNG", optimize=True)
    draw_icon(1024, True).save(
        OUT / "app_icon_foreground.png", "PNG", optimize=True
    )
    print(f"Wrote {OUT / 'app_icon.png'}")
    print(f"Wrote {OUT / 'app_icon_foreground.png'}")
    print("Next: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
