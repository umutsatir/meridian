#!/usr/bin/env python3
"""Compare a design reference render with an app render.

    python3 Scripts/compare.py <ref.png> <app.png> <out.png> [--regions 4]

Output image: reference | app | difference (white = identical, red = different) side by side.
Prints:
  size warnings        if the two images differ in size (the app image is resampled to the reference)
  mean abs diff %      0-100, mean absolute difference over all RGB channels
  worst regions        the 4 rectangles with the largest difference, as x,y,w,h in reference pixels

Needs Pillow and numpy (`python3 -c "import PIL, numpy"`). If missing:
    python3 -m venv .venv-tools && .venv-tools/bin/pip install pillow numpy
    .venv-tools/bin/python Scripts/compare.py ...
"""
import argparse
import sys

try:
    import numpy as np
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow/numpy missing. See the docstring: python3 -m venv .venv-tools && .venv-tools/bin/pip install pillow numpy")


def load(path):
    img = Image.open(path)
    if img.mode in ("RGBA", "LA", "P"):
        bg = Image.new("RGBA", img.size, (0, 0, 0, 255))
        bg.alpha_composite(img.convert("RGBA"))
        img = bg
    return img.convert("RGB")


def worst_regions(diff, count):
    """Greedy: score every grid-aligned window by mean diff, take the best, suppress overlaps."""
    h, w = diff.shape
    # integral image for fast window sums
    ii = np.pad(diff, ((1, 0), (1, 0))).cumsum(0).cumsum(1)

    def box(x, y, bw, bh):
        return ii[y + bh, x + bw] - ii[y, x + bw] - ii[y + bh, x] + ii[y, x]

    sizes = [(w // 6, h // 5), (w // 4, h // 4), (w // 8, h // 8)]
    cands = []
    for bw, bh in sizes:
        bw, bh = max(bw, 16), max(bh, 16)
        for y in range(0, h - bh + 1, max(1, bh // 2)):
            for x in range(0, w - bw + 1, max(1, bw // 2)):
                cands.append((box(x, y, bw, bh) / (bw * bh), x, y, bw, bh))
    cands.sort(reverse=True)
    picked = []
    for score, x, y, bw, bh in cands:
        if all(x + bw <= px or px + pw <= x or y + bh <= py or py + ph <= y for _, px, py, pw, ph in picked):
            picked.append((score, x, y, bw, bh))
        if len(picked) == count:
            break
    return picked


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref")
    ap.add_argument("app")
    ap.add_argument("out")
    ap.add_argument("--regions", type=int, default=4)
    args = ap.parse_args()

    ref, app = load(args.ref), load(args.app)
    if ref.size != app.size:
        print(f"WARNING: sizes differ, ref {ref.size[0]}x{ref.size[1]} vs app {app.size[0]}x{app.size[1]}; "
              f"resampling app to the reference size (score is less reliable).")
        ra, aa = ref.size[0] / ref.size[1], app.size[0] / app.size[1]
        if abs(ra - aa) > 0.01:
            print(f"WARNING: aspect ratios differ ({ra:.3f} vs {aa:.3f}); the app image is stretched.")
        app = app.resize(ref.size, Image.LANCZOS)

    a = np.asarray(ref, dtype=np.int16)
    b = np.asarray(app, dtype=np.int16)
    d = np.abs(a - b)
    per_pixel = d.mean(axis=2)                      # 0..255
    score = per_pixel.mean() / 255 * 100
    regions = worst_regions(per_pixel, args.regions)

    # difference image: white where equal, red intensity by difference (amplified x3)
    amp = np.clip(per_pixel * 3, 0, 255).astype(np.uint8)
    diff_rgb = np.stack([np.full_like(amp, 255), 255 - amp, 255 - amp], axis=2)
    diff_img = Image.fromarray(diff_rgb)

    ow, oh = ref.size
    pad, label = 12, 22
    sheet = Image.new("RGB", (ow * 3 + pad * 4, oh + pad * 2 + label), (24, 24, 28))
    draw = ImageDraw.Draw(sheet)
    for i, (img, name) in enumerate([(ref, "reference"), (app, "app"), (diff_img, f"difference  {score:.2f}%")]):
        x = pad + i * (ow + pad)
        draw.text((x, pad // 2), name, fill=(230, 230, 230))
        sheet.paste(img, (x, pad + label))
    # outline the worst regions on the difference panel
    for n, (s, x, y, bw, bh) in enumerate(regions, 1):
        ox, oy = pad + 2 * (ow + pad), pad + label
        draw.rectangle([ox + x, oy + y, ox + x + bw - 1, oy + y + bh - 1], outline=(0, 90, 255), width=2)
        draw.text((ox + x + 4, oy + y + 3), str(n), fill=(0, 90, 255))
    sheet.save(args.out)

    print(f"mean abs diff: {score:.2f}%   (0 = identical, 100 = opposite)")
    print("worst regions (x,y,w,h in reference px; mean diff %):")
    for n, (s, x, y, bw, bh) in enumerate(regions, 1):
        print(f"  {n}. {x},{y},{bw},{bh}   {s / 255 * 100:.1f}%")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
