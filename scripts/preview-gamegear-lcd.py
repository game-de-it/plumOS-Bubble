#!/usr/bin/env python3
"""Preview the Game Gear LCD shader without a device.

Reimplements configs/retroarch/shaders/*.glsl in numpy so the look can be
judged, and the arithmetic checked, on a build machine.  It does not compile
the GLSL - nothing here can - so a device run is still needed to prove the
shader loads.  What this does prove is what it will look like when it does.

    python3 scripts/preview-gamegear-lcd.py <160x144.png> <out-dir>
"""

import sys

import numpy as np
from PIL import Image

OUT_W, OUT_H = 640, 480
# 160x144 * 3 = 480x432, centred on the panel with a border.  Three is not a
# choice: the shader phases its structure on the source pixel, so it needs a
# whole number of output pixels per source pixel, and three is the largest that
# fits 480 rows.  plumos-retroarch-launch pins this with a custom viewport.
SCALE = 3

P = {
    "bleed_x": 1.00,
    "bleed_y": 0.60,
    "fringe": 0.33,
    "subpixel": 0.62,
    "subcells": 1.0,
    "rowgap": 0.80,
    "colgap": 0.35,
    "elemgap": 0.00,
    "black": 0.28,
    "white": 0.97,
    "sat": 0.60,
    "gamma": 0.90,
    "backlight": 0.28,
    "tint": 0.55,
    "bright": 2.30,
    "rise": 0.62,
    "fall": 0.34,
}


def response(frames):
    """Pass 1.  frames[0] is current, then progressively older."""
    cur = frames[0]
    weights = [0.42, 0.28, 0.18, 0.12]
    history = sum(w * f for w, f in zip(weights, frames[1:5]))
    rising = (cur >= history).astype(np.float32)
    speed = P["fall"] + (P["rise"] - P["fall"]) * rising
    return history + (cur - history) * speed


def taps(sigma, shift):
    """Three weights at -1, 0, +1 source pixels, centred at `shift`."""
    d = np.array([-1.0, 0.0, 1.0], np.float32) - shift
    w = np.exp(-0.5 * d * d / max(sigma * sigma, 1e-4))
    return w / max(w.sum(), 1e-6)


def panel(src):
    """Pass 2.  src is linear 0..1, shape (h, w, 3) at source resolution."""
    sh, sw = src.shape[:2]
    ow, oh = sw * SCALE, sh * SCALE

    ys, xs = np.mgrid[0:oh, 0:ow]
    u = (xs + 0.5) / ow
    v = (ys + 0.5) / oh
    cx = np.clip((u * sw).astype(np.int32), 0, sw - 1)
    cy = np.clip((v * sh).astype(np.int32), 0, sh - 1)

    # Diffusion and the offset between the three elements, in one 3x3 read.
    # The channels do not share a position - red's strip sits left of the cell
    # centre and blue's right of it - and that sub-pixel shift is folded into
    # the horizontal weights rather than into extra fetches.
    wx = np.stack([taps(P["bleed_x"], -P["fringe"]),
                   taps(P["bleed_x"], 0.0),
                   taps(P["bleed_x"], P["fringe"])], axis=1)   # (tap, channel)
    wy = taps(P["bleed_y"], 0.0)
    rgb = np.zeros((oh, ow, 3), np.float32)
    for j in range(3):
        yy = np.clip(cy + j - 1, 0, sh - 1)
        for i in range(3):
            xx = np.clip(cx + i - 1, 0, sw - 1)
            rgb += src[yy, xx] * wx[i] * wy[j]

    phase_x = (u * sw) % 1.0
    phase_y = (v * sh) % 1.0

    luma = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    rgb = luma[..., None] + (rgb - luma[..., None]) * P["sat"]
    rgb = np.clip(rgb, 0.0, 1.0) ** P["gamma"]
    rgb = P["black"] + rgb * (P["white"] - P["black"])

    tau = 2.0 * np.pi
    centres = np.array([1.0, 3.0, 5.0], np.float32) / 6.0
    sub_phase = ((u * sw) / P["subcells"]) % 1.0
    band = (np.floor(sub_phase * 3.0) + 0.5) / 3.0
    mask = 0.5 + 0.5 * np.cos(tau * (band[..., None] - centres))
    stripe = 1.0 + (2.0 * mask - 1.0) * P["subpixel"]
    stripe = stripe / (stripe @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]

    if P["elemgap"] > 1e-3:
        ep = np.abs(((u * sw) * 3.0 / P["subcells"]) % 1.0 - 0.5) * 2.0
        stripe = stripe * ((1.0 - P["elemgap"] * ep * ep) /
                           (1.0 - P["elemgap"] / 3.0))[..., None]

    ex = np.abs(phase_x - 0.5) * 2.0
    ey = np.abs(phase_y - 0.5) * 2.0
    grid = (1.0 - P["rowgap"] * ey * ey - P["colgap"] * ex * ex) / (
        1.0 - (P["rowgap"] + P["colgap"]) / 3.0)

    ccx = u - 0.5
    ccy = v - 0.42
    radial = 1.0 - (ccx * ccx + ccy * ccy) * 0.85
    edge = 1.0 - 0.18 * v
    back = 1.0 + (radial * edge - 1.0) * P["backlight"]

    lamp = np.array([1.0, 1.0, 1.0], np.float32) + (
        np.array([0.53, 0.76, 1.00], np.float32) - 1.0) * P["tint"]

    out = rgb * stripe * grid[..., None] * lamp * back[..., None]
    out = 1.0 - np.exp(-P["bright"] * np.maximum(out, 0.0))
    return np.clip(out, 0.0, 1.0)


def to_panel(img):
    """Centre a rendered frame on the 640x480 panel, as RetroArch would."""
    frame = np.zeros((OUT_H, OUT_W, 3), np.float32)
    h, w = img.shape[:2]
    y0 = (OUT_H - h) // 2
    x0 = (OUT_W - w) // 2
    frame[y0:y0 + h, x0:x0 + w] = img
    return Image.fromarray((frame * 255.0 + 0.5).astype(np.uint8))


def moving_square(step):
    """A bright block crossing a dark field, to show the response trail."""
    f = np.zeros((144, 160, 3), np.float32)
    f[:, :] = (0.06, 0.07, 0.10)
    x = 20 + step * 7
    f[60:84, x:x + 24] = (0.95, 0.90, 0.35)
    return f


def main():
    src_path = sys.argv[1] if len(sys.argv) > 1 else "art/title-gloc.png"
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "/tmp"

    src = np.asarray(Image.open(src_path).convert("RGB"), np.float32) / 255.0
    if src.shape[:2] != (144, 160):
        src = np.asarray(
            Image.open(src_path).convert("RGB").resize((160, 144), Image.NEAREST),
            np.float32) / 255.0

    plain = np.repeat(np.repeat(src, SCALE, axis=0), SCALE, axis=1)
    to_panel(plain).save("%s/lcd-off.png" % out_dir)
    to_panel(panel(src)).save("%s/lcd-on.png" % out_dir)

    # The response pass needs a history, so run a short motion sequence.
    seq = [moving_square(i) for i in range(12)]
    hist = [seq[-1 - i] for i in range(5)]
    to_panel(panel(seq[-1])).save("%s/lcd-motion-off.png" % out_dir)
    to_panel(panel(response(hist))).save("%s/lcd-motion-on.png" % out_dir)

    print("wrote lcd-off, lcd-on, lcd-motion-off, lcd-motion-on to", out_dir)


if __name__ == "__main__":
    main()
