#!/usr/bin/env python3
"""Regenerates every app icon, launch image and wordmark from the brand masters.

The masters live in assets/brand/source/ (traced from the owner's artwork):

  icon_s_1024.png              white "S" on solid navy, 1024 px, no alpha
  adaptive_foreground_432.png  white "S" on transparent, Android adaptive
                               foreground at xxxhdpi (108 dp, S inside the
                               66 dp safe zone)
  logo_navy.png, logo_white.png  the "studafy" wordmark, 2480 px wide
  *.svg                        vector masters, kept for future artwork

Every output below is only ever downscaled from those files. Run from the
repository root after changing a master:

  python3 scripts/brand/generate-icons.py

Needs Pillow and numpy (pip install pillow numpy).
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "brand" / "source"

# The brand navy. Also lib/core/studafy_design.dart (studafyNavy) and
# android/app/src/main/res/values/colors.xml.
NAVY = (0x16, 0x15, 0x51)

# The wordmark as StudafyLogo(size: 64) draws it on the launch hand-off
# (role_page.dart): 64 * 1.15 logical pixels tall. The native launch screens
# show it at the same size so the hand-off to Flutter does not jump.
LAUNCH_WORDMARK_HEIGHT_PT = 64 * 1.15

# In-app wordmark: the largest StudafyLogo is 73.6 logical px tall, so 80 px
# at 1x covers it, with 2.0x and 3.0x variants for denser screens.
APP_WORDMARK_HEIGHT_PX = 80

ANDROID_DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """High-quality downscale; alpha images are resized premultiplied so
    edges never pick up a dark or light fringe."""
    if image.mode == "RGBA":
        return image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    return image.resize(size, Image.LANCZOS)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def tight(image: Image.Image) -> Image.Image:
    """Crops transparent margins."""
    return image.crop(image.getchannel("A").getbbox())


def s_mask(icon: Image.Image) -> Image.Image:
    """The S of the square icon as an alpha mask (white on navy -> 0..255)."""
    rgb = np.asarray(icon.convert("RGB")).astype(np.float32)
    navy = np.array(NAVY, dtype=np.float32)
    # Distance from navy towards white, per pixel, using the channel with the
    # widest range so antialiased edges keep their coverage.
    coverage = (rgb[..., 1] - navy[1]) / (255 - navy[1])
    alpha = np.clip(coverage * 255 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(alpha)


def wordmark_at(art: Image.Image, height: float, scale: float) -> Image.Image:
    """The wordmark [height] logical px tall, at a device-pixel [scale]."""
    width = height * art.width / art.height
    return resize(art, (round(width * scale), round(height * scale)))


def white_on_transparent(mask: Image.Image) -> Image.Image:
    out = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    out.putalpha(mask)
    return out


def rounded_mask(size: int, box: tuple[int, int, int, int], radius: float):
    """Antialiased rounded-rectangle mask (drawn 4x and reduced)."""
    k = 4
    big = Image.new("L", (size * k, size * k), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [c * k for c in box], radius=radius * k, fill=255
    )
    return big.resize((size, size), Image.LANCZOS)


def circle_mask(size: int) -> Image.Image:
    k = 4
    big = Image.new("L", (size * k, size * k), 0)
    ImageDraw.Draw(big).ellipse([0, 0, size * k - 1, size * k - 1], fill=255)
    return big.resize((size, size), Image.LANCZOS)


def notification_icon(s_only: Image.Image, scale: float) -> Image.Image:
    """Android status bar icon for push: the white S alone, 24 dp, 20 dp
    tall. Android draws only its alpha, so the full-colour launcher icon
    would show as a plain white square."""
    canvas = round(24 * scale)
    s_h = round(20 * scale)
    s_w = round(s_h * s_only.width / s_only.height)
    out = Image.new("RGBA", (canvas, canvas), (255, 255, 255, 0))
    out.alpha_composite(
        resize(s_only, (s_w, s_h)),
        ((canvas - s_w) // 2, (canvas - s_h) // 2),
    )
    return out


def main() -> None:
    icon = Image.open(SOURCE / "icon_s_1024.png").convert("RGB")
    assert icon.size == (1024, 1024), "icon_s_1024.png must be 1024x1024"
    foreground = Image.open(SOURCE / "adaptive_foreground_432.png").convert("RGBA")
    navy_word = tight(Image.open(SOURCE / "logo_navy.png").convert("RGBA"))
    white_word = tight(Image.open(SOURCE / "logo_white.png").convert("RGBA"))
    aspect = navy_word.width / navy_word.height
    print(f"wordmark aspect {aspect:.4f} (studafyWordmarkAspect)")

    # In-app wordmarks, resolution-aware (Flutter picks 2.0x/3.0x itself).
    print("Flutter wordmarks")
    for name, art in (
        ("studafy_wordmark.png", navy_word),
        ("studafy_wordmark_white.png", white_word),
    ):
        for scale, folder in ((1, ""), (2, "2.0x"), (3, "3.0x")):
            out = wordmark_at(art, APP_WORDMARK_HEIGHT_PX, scale)
            save(out, ROOT / "assets" / "brand" / folder / name)

    # iOS: every AppIcon size, opaque (App Store rejects alpha).
    print("iOS AppIcon")
    ios_icons = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((ios_icons / "Contents.json").read_text())
    done: set[str] = set()
    for entry in contents["images"]:
        if entry["filename"] in done:
            continue
        done.add(entry["filename"])
        points = float(entry["size"].split("x")[0])
        px = round(points * int(entry["scale"].rstrip("x")))
        save(resize(icon, (px, px)), ios_icons / entry["filename"])

    # iOS launch screen: the white wordmark, centred on navy by
    # LaunchScreen.storyboard.
    print("iOS LaunchImage")
    launch = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        save(
            wordmark_at(white_word, LAUNCH_WORDMARK_HEIGHT_PT, scale),
            launch / f"LaunchImage{suffix}.png",
        )

    # Android.
    print("Android")
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    mask = s_mask(icon)
    s_only = tight(white_on_transparent(mask))
    for density, f in ANDROID_DENSITIES.items():
        mip = res / f"mipmap-{density}"
        legacy = round(48 * f)
        save(resize(icon, (legacy, legacy)), mip / "ic_launcher.png")
        round_icon = resize(icon, (legacy, legacy)).convert("RGBA")
        round_icon.putalpha(circle_mask(legacy))
        save(round_icon, mip / "ic_launcher_round.png")
        fg = round(108 * f)
        save(resize(foreground, (fg, fg)), mip / "ic_launcher_foreground.png")

        draw = res / f"drawable-{density}"
        # Pre-Android-12 launch: the white wordmark (launch_background.xml).
        save(
            wordmark_at(white_word, LAUNCH_WORDMARK_HEIGHT_PT, f),
            draw / "launch_wordmark.png",
        )
        # Android 12+ system splash: a centred icon only (no wordmark), 288 dp
        # with the S kept well inside the 192 dp circle the system masks to.
        # Same proportions as the adaptive foreground.
        canvas = round(288 * f)
        s_h = round(canvas * 188 / 432)
        s_w = round(s_h * s_only.width / s_only.height)
        splash = Image.new("RGBA", (canvas, canvas), (255, 255, 255, 0))
        splash.alpha_composite(
            resize(s_only, (s_w, s_h)),
            ((canvas - s_w) // 2, (canvas - s_h) // 2),
        )
        save(splash, draw / "splash_icon.png")
        # Push notifications (AndroidManifest.xml, default_notification_icon).
        save(notification_icon(s_only, f), draw / "ic_notification.png")

    # macOS: the S on a navy rounded square inside the standard 1024 grid
    # (824 px body, 100 px margin), with transparent corners.
    print("macOS AppIcon")
    mac = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if mac.exists():
        body = resize(icon, (824, 824)).convert("RGBA")
        mac_icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        mac_icon.paste(body, (100, 100))
        mac_icon.putalpha(rounded_mask(1024, (100, 100, 923, 923), 185))
        for px in (16, 32, 64, 128, 256, 512, 1024):
            save(resize(mac_icon, (px, px)), mac / f"app_icon_{px}.png")

    # Web (manifest icons and favicon).
    print("Web")
    web = ROOT / "web"
    if web.exists():
        for px in (192, 512):
            save(resize(icon, (px, px)), web / "icons" / f"Icon-{px}.png")
            save(resize(icon, (px, px)), web / "icons" / f"Icon-maskable-{px}.png")
        save(resize(icon, (32, 32)), web / "favicon.png")

    # Google Play store icon (512, opaque).
    print("Store")
    save(resize(icon, (512, 512)), ROOT / "docs" / "store" / "play_icon_512.png")


if __name__ == "__main__":
    main()
