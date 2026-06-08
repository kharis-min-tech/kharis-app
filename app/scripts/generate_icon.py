#!/usr/bin/env python3
"""
Kharis Church app icon generator — dove variant.
Creates a 1024x1024 PNG with a simplified dove silhouette in Kharis purple (#6B34FA)
on a dark (#0D0D0D) background with a subtle glow.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
BG = (13, 13, 13)          # #0D0D0D
DOVE = (107, 52, 250)       # #6B34FA
GLOW = (107, 52, 250, 60)   # translucent purple for glow

OUTPUT = os.path.join(os.path.dirname(__file__), "../assets/icon/icon.png")


def draw_dove(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float = 1.0):
    """Draw a simplified dove using ellipses, polygons, and arcs."""

    def s(v):
        return int(v * scale)

    # ── Body ──────────────────────────────────────────────────────────────────
    # Main ellipse: wide horizontal body
    bx, by, bw, bh = cx - s(200), cy - s(80), s(400), s(180)
    draw.ellipse([bx, by, bx + bw, by + bh], fill=DOVE)

    # ── Head ──────────────────────────────────────────────────────────────────
    hx, hy, hr = cx + s(155), cy - s(90), s(70)
    draw.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=DOVE)

    # ── Beak ──────────────────────────────────────────────────────────────────
    beak = [
        (hx + hr - s(5), hy),
        (hx + hr + s(55), hy + s(10)),
        (hx + hr, hy + s(25)),
    ]
    draw.polygon(beak, fill=DOVE)

    # ── Tail feathers ─────────────────────────────────────────────────────────
    tail_base_x = cx - s(200)
    tail = [
        (tail_base_x, cy + s(10)),
        (tail_base_x - s(80), cy + s(70)),
        (tail_base_x - s(50), cy + s(20)),
        (tail_base_x - s(100), cy + s(90)),
        (tail_base_x - s(20), cy + s(30)),
        (tail_base_x - s(110), cy + s(110)),
        (tail_base_x + s(10), cy + s(50)),
    ]
    draw.polygon(tail, fill=DOVE)

    # ── Wing (upper arc) ──────────────────────────────────────────────────────
    # Use pieslice to approximate wing arc
    wx, wy = cx - s(120), cy - s(220)
    ww, wh = s(380), s(280)
    draw.pieslice([wx, wy, wx + ww, wy + wh], start=200, end=360, fill=DOVE)

    # ── Wing tip feathers ─────────────────────────────────────────────────────
    for i, (dx, dy) in enumerate([
        (s(60), s(130)), (s(100), s(140)), (s(140), s(130)), (s(170), s(110)),
    ]):
        feather = [
            (cx - s(30) + i * s(30), cy + s(20)),
            (cx - s(60) + dx, cy - s(20) + dy),
            (cx - s(10) + i * s(30), cy + s(10)),
        ]
        draw.polygon(feather, fill=DOVE)

    # ── Eye (negative space) ─────────────────────────────────────────────────
    ex, ey, er = hx + s(20), hy - s(15), s(12)
    draw.ellipse([ex - er, ey - er, ex + er, ey + er], fill=BG)


def main():
    # Base layer
    img = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
    draw = ImageDraw.Draw(img)

    cx, cy = SIZE // 2, SIZE // 2 + 20

    # Glow layer — draw dove larger and blur
    glow_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    draw_dove(glow_draw, cx, cy, scale=1.08)
    # Tint glow
    for _ in range(3):
        blurred = glow_img.filter(ImageFilter.GaussianBlur(radius=30))
        img = Image.alpha_composite(img, blurred)

    # Final dove on top
    draw = ImageDraw.Draw(img)
    draw_dove(draw, cx, cy, scale=1.0)

    # Convert to RGB for PNG output (launcher icons must be RGB/RGBA)
    out_path = os.path.abspath(OUTPUT)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()
