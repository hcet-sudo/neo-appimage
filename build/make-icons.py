#!/usr/bin/env python3
"""Generate the icon for the neo AppImage: matrix-rain motif on a dark
rounded square, with the program name at the bottom — same visual family
as the chdman / unecm icons."""
from PIL import Image, ImageDraw, ImageFont

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def base_bg(size=256, radius=48):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # near-black rounded square (terminal backdrop)
    d.rounded_rectangle([8, 8, size - 8, size - 8], radius=radius,
                        fill=(14, 20, 16, 255), outline=(60, 160, 90, 255), width=4)
    return img, d


def rain_columns(d):
    # falling glyph columns: stacked rounded segments in matrix greens with
    # varying alpha; brightest segment at the head of each column
    greens = [(0, 255, 90), (0, 220, 80), (0, 180, 70), (0, 140, 60)]
    for cx, w, segs, seed in [(58, 12, 6, 3), (102, 10, 4, 5), (146, 12, 7, 2),
                              (190, 10, 5, 4)]:
        y = 34 + (seed * 9) % 22
        for i in range(segs):
            alpha = 110 + (i * 30)
            color = greens[(seed + i) % len(greens)] + (min(alpha, 255),)
            d.rounded_rectangle([cx - w // 2, y, cx + w // 2, y + 18],
                                radius=5, fill=color)
            y += 24
        # bright head glyph
        head = (140, 255, 170, 255)
        d.rounded_rectangle([cx - w // 2 - 1, y, cx + w // 2 + 1, y + 20],
                            radius=6, fill=head)


def make_neo(path):
    img, d = base_bg()
    rain_columns(d)
    f = ImageFont.truetype(FONT_BOLD, 52)
    tb = d.textbbox((0, 0), "neo", font=f)
    d.text(((256 - (tb[2] - tb[0])) / 2 - tb[0], 190), "neo", font=f,
           fill=(0, 230, 90, 255))
    img.save(path)


if __name__ == "__main__":
    import sys
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    make_neo(f"{outdir}/neo.png")
    print("icon written")
