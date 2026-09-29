#!/usr/bin/env python3
"""Generate the Tidy Up! app icon set into Assets.xcassets/AppIcon.appiconset."""
from PIL import Image, ImageDraw
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "ios/App/App/Assets.xcassets/AppIcon.appiconset"

CANDY = [0xFF3B5C, 0xFF8A00, 0xFFD60A, 0x7ED957, 0x00C2A8, 0x3AB6FF, 0x5B5FE9, 0xA259FF, 0xFF5FD2, 0x00B4D8]

def rgb(h):
    return ((h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF)

def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Background: deep plum gradient (approximated with horizontal bands).
    top, bottom = (43, 27, 77), (23, 16, 46)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)],
               fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    # Rounded mask.
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size, size], radius=int(size * 0.225), fill=255)
    # Three tubes with candy liquids.
    tubes = [
        (0.30, [0, 1, 2, 3]),
        (0.50, [4, 5, 6, 7]),
        (0.70, [8, 9, 0, 1]),
    ]
    tw, th = int(size * 0.16), int(size * 0.52)
    base_y = int(size * 0.78)
    for k, (fx, colors) in enumerate(tubes):
        cx = int(size * fx)
        lift = int(size * 0.03) if k == 1 else 0
        top_y = base_y - th - lift
        # liquids (bottom-up)
        seg_h = th // 4
        for i, c in enumerate(colors):
            y0 = base_y - lift - (i + 1) * seg_h + 4
            d.rounded_rectangle([cx - tw // 2 + 10, y0, cx + tw // 2 - 10, y0 + seg_h - 4],
                                radius=10, fill=rgb(CANDY[c]))
        # glossy surface on top segment
        d.ellipse([cx - tw // 2 + 16, top_y + 8, cx + tw // 2 - 16, top_y + 26],
                  fill=(255, 255, 255, 200))
        # glass outline
        d.rounded_rectangle([cx - tw // 2, top_y, cx + tw // 2, base_y - lift],
                            radius=int(tw * 0.28), outline=(255, 255, 255, 150),
                            width=max(3, size // 128))
        # sparkles
        for sx, sy, sr in [(cx + tw // 2 + 24, top_y - 20, 10), (cx - tw // 2 - 18, top_y + 40, 7)]:
            sr = max(3, int(sr * size / 1024))
            d.line([(sx - sr, sy), (sx + sr, sy)], fill=(255, 255, 255, 220), width=max(2, sr // 3))
            d.line([(sx, sy - sr), (sx, sy + sr)], fill=(255, 255, 255, 220), width=max(2, sr // 3))
    img.putalpha(mask)
    bg = Image.new("RGBA", (size, size), (23, 16, 46, 255))
    bg.paste(img, (0, 0), img)
    return bg.convert("RGB")

SIZES = [
    ("Icon-20@2x.png", 40, "20x20", "2x"),
    ("Icon-20@3x.png", 60, "20x20", "3x"),
    ("Icon-29@2x.png", 58, "29x29", "2x"),
    ("Icon-29@3x.png", 87, "29x29", "3x"),
    ("Icon-40@2x.png", 80, "40x40", "2x"),
    ("Icon-40@3x.png", 120, "40x40", "3x"),
    ("Icon-60@2x.png", 120, "60x60", "2x"),
    ("Icon-60@3x.png", 180, "60x60", "3x"),
    ("Icon-1024.png", 1024, "1024x1024", "1x"),
]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw_icon(1024)
    images = []
    for filename, px, size_str, scale in SIZES:
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(OUT / filename)
        images.append({"filename": filename, "idiom": "iphone",
                       "scale": scale, "size": size_str})
    (OUT / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print("wrote", len(images), "icons")

if __name__ == "__main__":
    main()
