#!/usr/bin/env python3
"""
Kharis Church app icon generator — simple 'K' fallback.
Creates a 1024x1024 PNG with a bold centred 'K' in Kharis purple (#6B34FA)
on a dark (#0D0D0D) background.
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
BG = (13, 13, 13, 255)       # #0D0D0D
PURPLE = (107, 52, 250, 255)  # #6B34FA
GLOW_ALPHA = 80

OUTPUT = os.path.join(os.path.dirname(__file__), "../assets/icon/icon.png")

FONT_SIZE = 620
LETTER = "K"


def find_font() -> ImageFont.FreeTypeFont | None:
    """Try to find a bold sans-serif font on the system."""
    candidates = [
        # macOS
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/SF-Pro-Display-Bold.otf",
        # Linux
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, FONT_SIZE)
            except Exception:
                continue
    return None


def draw_letter_polygon(draw: ImageDraw.ImageDraw, cx: int, cy: int, color, scale: float = 1.0):
    """Draw a bold K using polygons — no font dependency."""

    def s(v):
        return int(v * scale)

    sw = s(85)   # stroke width
    h  = s(560)  # total height
    arm = s(280) # arm length (diagonal)

    top    = cy - h // 2
    bottom = cy + h // 2
    left   = cx - s(180)
    mid    = cx - s(40)   # where diagonals meet the vertical bar
    right  = cx + s(180)

    # Vertical bar
    draw.rectangle([left, top, left + sw, bottom], fill=color)

    # Upper diagonal arm  ╱
    upper_arm = [
        (mid, cy - s(10)),
        (right - sw, top),
        (right, top),
        (right, top + sw),
        (mid + sw, cy + s(10)),
    ]
    draw.polygon(upper_arm, fill=color)

    # Lower diagonal arm  ╲
    lower_arm = [
        (mid, cy + s(10)),
        (right - sw, bottom),
        (right, bottom),
        (right, bottom - sw),
        (mid + sw, cy - s(10)),
    ]
    draw.polygon(lower_arm, fill=color)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), BG)
    cx, cy = SIZE // 2, SIZE // 2

    # Glow pass
    glow_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    glow_color = (*PURPLE[:3], GLOW_ALPHA)
    draw_letter_polygon(glow_draw, cx, cy, glow_color, scale=1.0)
    blurred = glow_img.filter(ImageFilter.GaussianBlur(radius=40))
    for _ in range(2):
        img = Image.alpha_composite(img, blurred)

    # Try system font first, fall back to polygon K
    font = find_font()
    if font:
        draw_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(draw_layer)
        bbox = d.textbbox((0, 0), LETTER, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = cx - tw // 2 - bbox[0]
        ty = cy - th // 2 - bbox[1]
        d.text((tx, ty), LETTER, font=font, fill=PURPLE)
        img = Image.alpha_composite(img, draw_layer)
    else:
        draw = ImageDraw.Draw(img)
        draw_letter_polygon(draw, cx, cy, PURPLE, scale=1.0)

    # Rounded-rect mask (optional — keeps square for flutter_launcher_icons)
    out_path = os.path.abspath(OUTPUT)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()
