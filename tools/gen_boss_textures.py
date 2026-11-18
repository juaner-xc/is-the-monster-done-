import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(r"D:\Documents\GitHub\is-the-monster-done-\assets\chapter2\textures\boss")
OUT.mkdir(parents=True, exist_ok=True)
random.seed(20261116)
rng = np.random.default_rng(20261116)


def smooth_noise(size, scale, octaves=3):
    out = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        s = max(2, int(scale / (2 ** o)))
        small = rng.random((s, s)).astype(np.float32)
        up = np.array(Image.fromarray((small * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), dtype=np.float32) / 255.0
        out += up * amp
        total += amp
        amp *= 0.5
    return out / total


def normal_from_height(h, strength=2.0):
    h = h.astype(np.float32)
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= ln
    ny /= ln
    nz /= ln
    rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
    return Image.fromarray((rgb * 255).clip(0, 255).astype(np.uint8), "RGB")


def save(name, img, normal=False):
    img.save(OUT / name)
    if normal:
        n = normal_from_height(np.array(img.convert("L"), dtype=np.float32) / 255.0, 2.2)
        n.save(OUT / (name.replace(".png", "_normal.png")))


def stone_texture(size=1024):
    img = Image.new("RGB", (size, size), (42, 39, 35))
    draw = ImageDraw.Draw(img)
    height = Image.new("L", (size, size), 120)
    hd = ImageDraw.Draw(height)
    y = 0
    row = 0
    while y < size:
        bh = random.randint(70, 120)
        x = -random.randint(0, 120)
        while x < size:
            bw = random.randint(110, 220)
            base = random.randint(34, 58)
            col = (base + random.randint(-5, 7), base - 3 + random.randint(-4, 6), base - 7 + random.randint(-4, 5))
            draw.rectangle([x + 4, y + 4, x + bw - 4, y + bh - 4], fill=col)
            hd.rectangle([x + 4, y + 4, x + bw - 4, y + bh - 4], fill=random.randint(150, 185))
            bx0, by0, bx1, by1 = x + 4, y + 4, x + bw - 4, y + bh - 4
            draw.line([bx0, by0, bx1, by0], fill=(base + 28, base + 22, base + 15), width=3)
            draw.line([bx0, by0, bx0, by1], fill=(base + 24, base + 18, base + 12), width=2)
            draw.line([bx0, by1, bx1, by1], fill=(20, 18, 16), width=4)
            x += bw
        y += bh
        row += 1
    arr = np.array(img, dtype=np.float32)
    n = smooth_noise(size, 96, 4)
    n2 = smooth_noise(size, 18, 2)
    arr += (n * 26.0 + n2 * 10.0 - 18.0)[..., None]
    # soot and rust streaks
    soot = smooth_noise(size, 220, 3)
    arr = arr * (0.65 + 0.55 * soot[..., None])
    rust = smooth_noise(size, 70, 3)
    rust_mask = np.clip((rust - 0.62) * 4.0, 0, 1)
    arr[..., 0] += rust_mask * 52
    arr[..., 1] += rust_mask * 16
    arr[..., 2] += rust_mask * 5
    # cracks
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(img)
    for _ in range(36):
        x = random.randint(0, size)
        y = random.randint(0, size)
        pts = [(x, y)]
        for _ in range(random.randint(2, 5)):
            x += random.randint(-45, 45)
            y += random.randint(-30, 45)
            pts.append((x, y))
        draw.line(pts, fill=(13, 12, 11), width=random.randint(1, 3))
    img = img.filter(ImageFilter.GaussianBlur(0.35))
    save("boss_stone_albedo.png", img, True)


def floor_texture(size=1024):
    img = Image.new("RGB", (size, size), (34, 31, 27))
    draw = ImageDraw.Draw(img)
    cells = 4
    step = size // cells
    for gy in range(cells):
        for gx in range(cells):
            cx, cy = gx * step, gy * step
            pts = []
            for px, py in [(0, 0), (step, 0), (step, step), (0, step)]:
                pts.append((cx + px + random.randint(-18, 18), cy + py + random.randint(-18, 18)))
            base = random.randint(42, 66)
            col = (base, base - 4, base - 8)
            draw.polygon(pts, fill=col, outline=(18, 16, 14))
            draw.line(pts + [pts[0]], fill=(18, 16, 14), width=5)
    arr = np.array(img, dtype=np.float32)
    arr += (smooth_noise(size, 60, 4) * 28 - 14)[..., None]
    soot = smooth_noise(size, 260, 3)
    arr *= (0.7 + 0.5 * soot[..., None])
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(img)
    for _ in range(28):
        x = random.randint(0, size)
        y = random.randint(0, size)
        pts = [(x, y)]
        for _ in range(4):
            x += random.randint(-35, 35)
            y += random.randint(-25, 35)
            pts.append((x, y))
        draw.line(pts, fill=(14, 12, 10), width=random.randint(1, 3))
    img = img.filter(ImageFilter.GaussianBlur(0.3))
    save("boss_floor_albedo.png", img, True)


def metal_texture(size=1024):
    img = Image.new("RGB", (size, size), (38, 35, 32))
    draw = ImageDraw.Draw(img)
    # plate seams
    for y in range(0, size, 256):
        draw.line([(0, y), (size, y)], fill=(15, 14, 13), width=8)
    for x in range(0, size, 256):
        draw.line([(x, 0), (x, size)], fill=(18, 16, 15), width=6)
    # rivets
    for y in range(40, size, 120):
        for x in range(40, size, 120):
            draw.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(86, 82, 74), outline=(16, 15, 14), width=2)
    arr = np.array(img, dtype=np.float32)
    hammer = smooth_noise(size, 38, 3)
    arr += (hammer[..., None] - 0.5) * 34
    rust = smooth_noise(size, 95, 4)
    rust_mask = np.clip((rust - 0.58) * 3.8, 0, 1)
    arr[..., 0] += rust_mask * 100
    arr[..., 1] += rust_mask * 35
    arr[..., 2] += rust_mask * 8
    soot = smooth_noise(size, 280, 3)
    arr *= (0.65 + 0.55 * soot[..., None])
    # scratches
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(img)
    for _ in range(70):
        x, y = random.randint(0, size), random.randint(0, size)
        ln = random.randint(10, 70)
        draw.line([(x, y), (x + ln, y + random.randint(-6, 6))], fill=(105, 100, 92), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.3))
    save("boss_metal_albedo.png", img, True)


def brass_texture(size=512):
    img = Image.new("RGB", (size, size), (120, 84, 35))
    arr = np.array(img, dtype=np.float32)
    arr += (smooth_noise(size, 60, 3)[..., None] - 0.5) * 50
    patina = smooth_noise(size, 120, 3)
    mask = np.clip((patina - 0.58) * 3.0, 0, 1)
    arr[..., 0] -= mask * 45
    arr[..., 1] += mask * 18
    arr[..., 2] -= mask * 20
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    save("boss_brass_albedo.png", img, True)


def banner_texture(w=512, h=1024):
    img = Image.new("RGBA", (w, h), (80, 9, 7, 255))
    arr = np.array(img, dtype=np.float32)
    cloth = smooth_noise(max(w, h), 20, 2)[:h, :w]
    arr[..., 0] += (cloth - 0.5) * 18
    arr[..., 1] += (cloth - 0.5) * 10
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
    draw = ImageDraw.Draw(img)
    # gold border
    draw.rectangle([10, 10, w - 10, h - 10], outline=(190, 145, 55, 255), width=10)
    # furnace emblem
    cx, cy = w // 2, int(h * 0.38)
    draw.ellipse([cx - 105, cy - 105, cx + 105, cy + 105], outline=(205, 160, 65, 255), width=9)
    draw.ellipse([cx - 75, cy - 75, cx + 75, cy + 75], fill=(35, 8, 6, 255), outline=(205, 160, 65, 255), width=5)
    for i in range(5):
        a = -math.pi / 2 + i * math.tau / 5
        draw.line([(cx, cy), (cx + math.cos(a) * 62, cy + math.sin(a) * 62)], fill=(205, 160, 65, 255), width=6)
    # tattered lower edge
    draw.polygon([(0, h), (w, h), (w, h - 50), (w * 0.75, h - 20), (w * 0.5, h - 60), (w * 0.25, h - 20), (0, h - 50)],
                 fill=(25, 5, 4, 255))
    img.save(OUT / "boss_banner.png")


def lava_texture(w=512, h=1024):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n = smooth_noise(max(w, h), 50, 4)
    n = np.array(Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0
    crack = np.abs(np.sin((xx / w * 12.0 + n * 4.0) * math.pi))
    heat = np.clip(1.0 - crack * 1.6, 0, 1) ** 1.4
    heat = np.clip(heat * 0.9 + n * 0.25, 0, 1)
    r = 120 + heat * 135
    g = 25 + heat * 95
    b = 5 + heat * 20
    img = Image.fromarray(np.stack([r, g, b], axis=-1).clip(0, 255).astype(np.uint8), "RGB")
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save(OUT / "boss_lava_albedo.png")


def haze_texture(size=512):
    n = smooth_noise(size, 120, 4)
    a = np.clip((n - 0.35) * 1.5, 0, 1) ** 1.2
    rgb = np.zeros((size, size, 4), dtype=np.float32)
    rgb[..., 0] = 70
    rgb[..., 1] = 105
    rgb[..., 2] = 150
    rgb[..., 3] = a * 110
    Image.fromarray(rgb.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(8)).save(OUT / "boss_haze.png")


stone_texture()
floor_texture()
metal_texture()
brass_texture()
banner_texture()
lava_texture()
haze_texture()
print("generated", sorted(p.name for p in OUT.glob("*.png")))
