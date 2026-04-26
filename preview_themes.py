"""
preview_themes.py — 8 premium aesthetic presets for workout share cards.
Outputs: preview_themes_grid.jpg (4×2 grid)
"""

from PIL import Image, ImageFilter, ImageEnhance, ImageDraw, ImageFont
import numpy as np
import os

SRC = "IMG_AF99C45A0D4E-1.jpeg"
OUT = "preview_themes_grid.jpg"

PANEL_W, PANEL_H = 540, 960
LABEL_H = 68

# ── Utility ───────────────────────────────────────────────────────────────────

def load(path):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    target = 9 / 16
    if w / h > target:
        new_w = int(h * target)
        img = img.crop(((w - new_w) // 2, 0, (w - new_w) // 2 + new_w, h))
    else:
        new_h = int(w / target)
        img = img.crop((0, (h - new_h) // 2, w, (h - new_h) // 2 + new_h))
    return img.resize((PANEL_W, PANEL_H), Image.LANCZOS)

def f2u(arr): return (np.clip(arr, 0, 1) * 255).astype(np.uint8)
def u2f(img): return np.array(img, dtype=np.float32) / 255.0

def lum(arr):
    return 0.299 * arr[..., 0] + 0.587 * arr[..., 1] + 0.114 * arr[..., 2]

def desaturate(arr, amount=1.0):
    l = lum(arr)[..., np.newaxis]
    return arr * (1 - amount) + l * amount

def apply_curve(channel, points):
    """Apply a piecewise tone curve to a 0..1 float channel."""
    xs = np.array([p[0] for p in points], dtype=np.float32)
    ys = np.array([p[1] for p in points], dtype=np.float32)
    return np.clip(np.interp(channel, xs, ys), 0, 1)

def s_curve(arr, strength=0.18):
    pts = [(0, 0), (0.25, 0.25 - strength), (0.5, 0.5),
           (0.75, 0.75 + strength), (1, 1)]
    result = arr.copy()
    for c in range(3):
        result[..., c] = apply_curve(arr[..., c], pts)
    return result

def split_tone(arr, shadow_rgb, highlight_rgb, shadow_str=0.28, hi_str=0.28):
    """
    Blend a colour into shadows and a different colour into highlights
    based on luminance masks — the core of any cinematic grade.
    shadow_rgb / highlight_rgb: tuples of (R, G, B) in 0..1
    """
    l = lum(arr)
    # Shadow weight peaks at 0, falls to 0 at ~0.5
    sw = np.clip(1.0 - l * 2.0, 0, 1)[..., np.newaxis] * shadow_str
    # Highlight weight peaks at 1, falls to 0 at ~0.5
    hw = np.clip((l - 0.5) * 2.0, 0, 1)[..., np.newaxis] * hi_str
    s = np.array(shadow_rgb, dtype=np.float32)
    h = np.array(highlight_rgb, dtype=np.float32)
    return np.clip(arr + sw * (s - arr) + hw * (h - arr), 0, 1)

def add_grain(arr, strength=0.035, size=1):
    noise = np.random.normal(0, strength, arr.shape).astype(np.float32)
    return np.clip(arr + noise, 0, 1)

def vignette(arr, strength=0.45, radius=0.65):
    h, w = arr.shape[:2]
    Y, X = np.ogrid[:h, :w]
    dist = np.sqrt(((X / w) - 0.5)**2 + ((Y / h) - 0.5)**2)
    dist = dist / (np.sqrt(0.5) * radius)
    vig = 1.0 - strength * np.clip(dist, 0, 1)**2
    return np.clip(arr * vig[..., np.newaxis], 0, 1)

def lift_blacks(arr, amount=0.04):
    return arr * (1 - amount) + amount  # milky matte

def crush_blacks(arr, threshold=0.08):
    return np.clip(arr - threshold, 0, 1) / (1 - threshold)

def adjust_wb(arr, r=1.0, g=1.0, b=1.0):
    result = arr.copy()
    result[..., 0] = np.clip(arr[..., 0] * r, 0, 1)
    result[..., 1] = np.clip(arr[..., 1] * g, 0, 1)
    result[..., 2] = np.clip(arr[..., 2] * b, 0, 1)
    return result

def boost_saturation(arr, factor=1.4):
    l = lum(arr)[..., np.newaxis]
    return np.clip(l + factor * (arr - l), 0, 1)

def add_overlay_card(arr):
    """Add a realistic frosted stats card overlay for context."""
    h, w = arr.shape[:2]
    overlay = arr.copy()
    # Card region: bottom ~35% of frame, left-aligned
    cy, cx = int(h * 0.62), int(w * 0.05)
    ch, cw = int(h * 0.30), int(w * 0.90)
    # Darken card area slightly (simulates frosted glass)
    overlay[cy:cy+ch, cx:cx+cw] = np.clip(
        overlay[cy:cy+ch, cx:cx+cw] * 0.25 + 0.08, 0, 1)
    return overlay

# ── 8 Presets ─────────────────────────────────────────────────────────────────

def preset_cinematic(arr):
    """Teal & Orange — Hollywood blockbuster grade. Cool shadows, warm highlights."""
    arr = s_curve(arr, strength=0.12)
    arr = split_tone(arr,
        shadow_rgb=(0.05, 0.18, 0.22),    # deep teal
        highlight_rgb=(0.92, 0.62, 0.20),  # warm orange
        shadow_str=0.32, hi_str=0.28)
    arr = vignette(arr, strength=0.35)
    return arr

def preset_portra(arr):
    """Portra 400 — Kodak warm film stock. Flattering skin, creamy highlights."""
    arr = adjust_wb(arr, r=1.08, g=1.02, b=0.88)   # warm shift
    arr = boost_saturation(arr, factor=1.15)
    # Gentle S-curve
    arr = s_curve(arr, strength=0.08)
    # Lift blacks — film base prevents true black
    arr = lift_blacks(arr, amount=0.025)
    arr = split_tone(arr,
        shadow_rgb=(0.18, 0.12, 0.07),    # warm amber shadows
        highlight_rgb=(1.0, 0.97, 0.88),   # creamy warm whites
        shadow_str=0.12, hi_str=0.10)
    arr = add_grain(arr, strength=0.018)
    return arr

def preset_bleach_bypass(arr):
    """Bleach Bypass — chemical process, silver overlay, crushed contrast."""
    # Blend colour with B&W (silver overlay)
    bw = desaturate(arr, amount=1.0)
    arr = arr * 0.35 + bw * 0.65          # 65% desaturated
    # Extreme contrast
    arr = s_curve(arr, strength=0.28)
    arr = crush_blacks(arr, threshold=0.06)
    # Slight cool cast (silver/chemical feel)
    arr = adjust_wb(arr, r=0.97, g=0.98, b=1.04)
    arr = add_grain(arr, strength=0.030)
    arr = vignette(arr, strength=0.40)
    return arr

def preset_classic_chrome(arr):
    """Fuji Classic Chrome — documentary muted. Slightly faded, cyan shadows."""
    arr = desaturate(arr, amount=0.30)     # partial desaturation
    arr = lift_blacks(arr, amount=0.055)   # matte/faded base
    # Flat contrast — more linear
    arr = s_curve(arr, strength=0.06)
    arr = split_tone(arr,
        shadow_rgb=(0.10, 0.14, 0.18),     # cool blue-gray shadows
        highlight_rgb=(0.96, 0.93, 0.87),  # slightly warm highlights
        shadow_str=0.20, hi_str=0.10)
    # Reduce red channel slightly (magazine desaturation of skin)
    arr[..., 0] = np.clip(arr[..., 0] * 0.95, 0, 1)
    arr = add_grain(arr, strength=0.022)
    return arr

def preset_moody(arr):
    """Dark & Moody — intense split-tone, cool deep shadows, amber glow highlights."""
    arr = desaturate(arr, amount=0.20)
    arr = s_curve(arr, strength=0.22)
    arr = crush_blacks(arr, threshold=0.05)
    arr = split_tone(arr,
        shadow_rgb=(0.04, 0.06, 0.14),     # deep blue-black shadows
        highlight_rgb=(0.95, 0.78, 0.40),   # warm amber glow
        shadow_str=0.40, hi_str=0.30)
    arr = vignette(arr, strength=0.50)
    arr = add_grain(arr, strength=0.020)
    return arr

def preset_golden_hour(arr):
    """Golden Hour — warm sun-drenched colour grade. Optimistic, aspirational."""
    arr = adjust_wb(arr, r=1.14, g=1.05, b=0.78)
    arr = boost_saturation(arr, factor=1.20)
    arr = lift_blacks(arr, amount=0.03)
    arr = s_curve(arr, strength=0.07)
    arr = split_tone(arr,
        shadow_rgb=(0.20, 0.13, 0.04),     # warm brown shadows (no cool)
        highlight_rgb=(1.0, 0.94, 0.70),    # golden warm whites
        shadow_str=0.15, hi_str=0.18)
    arr = vignette(arr, strength=0.25)
    return arr

def preset_grit(arr):
    """GRIT — raw B&W, crushed blacks, aggressive grain, max muscle definition."""
    arr = desaturate(arr, amount=1.0)
    # Aggressive S-curve to punch up contrast
    pts = [(0, 0), (0.15, 0.05), (0.40, 0.32), (0.60, 0.70), (0.85, 0.95), (1, 1)]
    for c in range(3):
        arr[..., c] = apply_curve(arr[..., c], pts)
    arr = crush_blacks(arr, threshold=0.07)
    arr = add_grain(arr, strength=0.048)
    arr = vignette(arr, strength=0.38)
    return arr

def preset_velvia(arr):
    """Fuji Velvia — hyper-saturated, punchy, vivid. Electric gym energy."""
    arr = boost_saturation(arr, factor=1.65)
    arr = s_curve(arr, strength=0.20)
    arr = crush_blacks(arr, threshold=0.04)
    arr = split_tone(arr,
        shadow_rgb=(0.04, 0.04, 0.12),     # deep cool blacks
        highlight_rgb=(1.0, 0.98, 0.88),    # bright clean whites
        shadow_str=0.15, hi_str=0.10)
    arr = vignette(arr, strength=0.30)
    return arr

PRESETS = [
    ("CINEMATIC",    preset_cinematic),
    ("PORTRA",       preset_portra),
    ("BLEACH",       preset_bleach_bypass),
    ("CHROME",       preset_classic_chrome),
    ("MOODY",        preset_moody),
    ("GOLDEN HOUR",  preset_golden_hour),
    ("GRIT",         preset_grit),
    ("VELVIA",       preset_velvia),
]

# ── Grid ──────────────────────────────────────────────────────────────────────

def make_panel(img_arr, name):
    filtered = Image.fromarray(f2u(img_arr))

    COLS_COUNT = 4
    canvas = Image.new("RGB", (PANEL_W, PANEL_H + LABEL_H), (12, 12, 12))
    canvas.paste(filtered, (0, 0))
    draw = ImageDraw.Draw(canvas)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 28)
    except Exception:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
        except Exception:
            font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), name, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (PANEL_W - tw) // 2
    ty = PANEL_H + (LABEL_H - th) // 2
    draw.text((tx, ty), name, fill=(210, 210, 210), font=font)
    return canvas

def make_grid():
    np.random.seed(42)
    base = load(SRC)
    arr = u2f(base)

    COLS = 4
    ROWS = 2
    GAP = 6
    total_w = COLS * PANEL_W + (COLS - 1) * GAP
    total_h = ROWS * (PANEL_H + LABEL_H) + (ROWS - 1) * GAP
    grid = Image.new("RGB", (total_w, total_h), (6, 6, 6))

    for i, (name, fn) in enumerate(PRESETS):
        panel_arr = fn(arr.copy())
        panel = make_panel(panel_arr, name)
        col = i % COLS
        row = i // COLS
        x = col * (PANEL_W + GAP)
        y = row * (PANEL_H + LABEL_H + GAP)
        grid.paste(panel, (x, y))
        print(f"  ✓ {name}")

    grid.save(OUT, quality=93)
    print(f"\nSaved → {OUT}  ({total_w}×{total_h})")

if __name__ == "__main__":
    print("Generating 8 presets…")
    make_grid()
