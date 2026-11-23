"""Draws the app icon (a brass cloche on warm charcoal) and writes every size
Android and the web build need. Run from app/: python3 tool/make_icons.py
Needs Pillow."""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
BRASS = (201, 165, 91, 255)
BRASS_HI = (230, 199, 122, 255)


def background(size):
    img = Image.new('RGBA', (size, size), (18, 16, 14, 255))
    # A warm glow behind the cloche, like a pendant lamp.
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    r = int(size * 0.42)
    c = size // 2
    d.ellipse((c - r, int(c * 0.92) - r, c + r, int(c * 0.92) + r), fill=(120, 80, 36, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    img.alpha_composite(glow)
    return img


def cloche(size, scale=1.0):
    """The cloche in brass line work, centred, on a transparent layer."""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = size * 0.6 * scale
    cx = size / 2
    cy = size * 0.56  # centre of the dome's circle
    lw = max(2, int(size * 0.032 * scale))
    r = w / 2
    # Dome.
    d.arc((cx - r, cy - r, cx + r, cy + r), 180, 360, fill=BRASS, width=lw)
    # Rim, then the plate.
    rim = cy + lw * 0.1
    d.line((cx - r * 1.18, rim, cx + r * 1.18, rim), fill=BRASS, width=lw)
    plate = rim + w * 0.12
    d.line((cx - r * 0.92, plate, cx + r * 0.92, plate), fill=BRASS, width=lw)
    # Knob.
    kr = w * 0.055
    ky = cy - r - kr * 0.7
    d.ellipse((cx - kr, ky - kr, cx + kr, ky + kr), outline=BRASS, width=lw)
    # Highlight on the dome.
    hi = r - lw * 2.4
    d.arc((cx - hi, cy - hi, cx + hi, cy + hi), 205, 240, fill=BRASS_HI, width=max(1, lw // 2))
    return layer


def full_icon(size, rounded=False):
    big = background(S)
    big.alpha_composite(cloche(S))
    # Hairline brass frame.
    d = ImageDraw.Draw(big)
    inset = int(S * 0.06)
    d.rounded_rectangle((inset, inset, S - inset, S - inset), radius=int(S * 0.14), outline=(201, 165, 91, 90),
                        width=max(2, S // 256))
    img = big.resize((size, size), Image.LANCZOS)
    if rounded:
        mask = Image.new('L', (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.22), fill=255)
        img.putalpha(mask)
    return img


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


res = 'android/app/src/main/res'
for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    save(full_icon(px, rounded=True), f'{res}/mipmap-{name}/ic_launcher.png')
    # Adaptive icon layers (Android 8+): 108dp canvas, art inside the 66dp safe zone.
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    fg.alpha_composite(cloche(S, scale=0.62))
    save(fg.resize((int(px * 108 / 48),) * 2, Image.LANCZOS), f'{res}/drawable-{name}/ic_launcher_foreground.png')
os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
with open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''')
with open(f'{res}/values/ic_launcher_background.xml', 'w') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#12100E</color>
</resources>
''')
save(full_icon(192), 'web/icons/Icon-192.png')
save(full_icon(512), 'web/icons/Icon-512.png')
save(full_icon(192), 'web/icons/Icon-maskable-192.png')
save(full_icon(512), 'web/icons/Icon-maskable-512.png')
save(full_icon(64, rounded=True), 'web/favicon.png')
save(full_icon(512, rounded=True), '../docs/app-icon.png')
