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
INTEGER_W, INTEGER_H = 480, 432

P = {
    "bleed_x": 0.85,
    "bleed_y": 0.45,
    "fringe": 0.25,
    "lumableed": 0.18,
    "smear_up": 0.18,
    "smear_luma": 1.00,
    "center_dark": 0.20,
    "dark_smear": 0.75,
    "subpixel": 0.62,
    "aperture": 0.88,
    "balance": 0.00,
    "subcells": 1.0,
    "rowgap": 0.80,
    "colgap": 0.35,
    "elemgap": 0.35,
    "black": 0.14,
    "white": 0.97,
    "sat": 0.55,
    "bluesat": 0.90,
    "blueweak": 0.14,
    "gamma": 1.35,
    "backlight": 0.28,
    "tint": 0.55,
    "bright": 2.60,
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


def periodic_box_integral(x, a, b):
    whole = np.floor(x)
    return whole * (b - a) + np.clip(np.mod(x, 1.0) - a, 0.0, b - a)


def periodic_box_coverage(centre, width, a, b):
    half = 0.5 * width
    return (periodic_box_integral(centre + half, a, b) -
            periodic_box_integral(centre - half, a, b)) / max(width, 1e-6)


def edge2_integral(x):
    whole = np.floor(x)
    p = np.mod(x, 1.0) - 0.5
    return whole / 3.0 + (4.0 / 3.0) * p * p * p + 1.0 / 6.0


def edge2_coverage(centre, width):
    half = 0.5 * width
    return (edge2_integral(centre + half) -
            edge2_integral(centre - half)) / max(width, 1e-6)


def panel(src, ow=OUT_W, oh=OUT_H):
    """Pass 2.  src is linear 0..1, shape (h, w, 3) at source resolution."""
    sh, sw = src.shape[:2]
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
    wy = taps(P["bleed_y"], P["smear_up"])
    diffused = np.zeros((oh, ow, 3), np.float32)
    for j in range(3):
        yy = np.clip(cy + j - 1, 0, sh - 1)
        for i in range(3):
            xx = np.clip(cx + i - 1, 0, sw - 1)
            diffused += src[yy, xx] * wx[i] * wy[j]

    panel_luma = np.array([0.299, 0.587, 0.114], np.float32)
    centre = src[cy, cx]
    centre_luma = centre @ panel_luma
    diffused_luma = diffused @ panel_luma
    kept_luma = centre_luma + (diffused_luma - centre_luma) * P["lumableed"]
    rgb = diffused + (kept_luma - diffused_luma)[..., None]
    lower_rgb = src[np.clip(cy + 1, 0, sh - 1), cx]
    current_row_luma = rgb @ panel_luma
    lower_row_luma = lower_rgb @ panel_luma
    # Horizontal CCFL tube/reflector model.  Treat the lamp as a line segment,
    # not a point: most of its length shares one vertical falloff and only its
    # ends round away.  Match the GLSL's physical-aspect correction exactly.
    beyond_end = np.maximum(np.abs(u - 0.5) - 0.38, 0.0) * (ow / oh)
    tube_distance = np.sqrt(beyond_end * beyond_end + (v - 0.5) ** 2)
    t = np.clip(tube_distance / 0.56, 0.0, 1.0)
    edge_response = t * t * (3.0 - 2.0 * t)
    bright_row_mix = P["smear_luma"] * (1.0 - edge_response)
    dark_row_mix = (P["center_dark"] +
                    (P["dark_smear"] - P["center_dark"]) * edge_response)
    row_mix = np.where(lower_row_luma <= current_row_luma,
                       dark_row_mix, bright_row_mix)
    rgb += (lower_rgb - rgb) * row_mix[..., None]

    phase_x = (u * sw) % 1.0
    phase_y = (v * sh) % 1.0

    # The blue filter is the weakest layer on an STN panel: it separates blue
    # from the rest of the backlight poorly, so blue content arrives washed
    # out in colour but not in brightness - hence the luminance is put back.
    if P["blueweak"] > 1e-3:
        L = np.array([0.299, 0.587, 0.114], np.float32)
        before = rgb @ L
        washed = rgb + P["blueweak"] * rgb[..., 2:3] * np.array([0.0, 1.0, 0.0], np.float32)
        rgb = washed * (before / np.maximum(washed @ L, 1e-5))[..., None]

    luma = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    blue_dom = np.clip(
        (rgb[..., 2] - np.maximum(rgb[..., 0], rgb[..., 1])) /
        np.maximum(rgb[..., 2], 1e-5), 0.0, 1.0)
    panel_sat = P["sat"] + (P["bluesat"] - P["sat"]) * blue_dom
    rgb = luma[..., None] + (rgb - luma[..., None]) * panel_sat[..., None]
    rgb = np.clip(rgb, 0.0, 1.0) ** P["gamma"]
    black_floor = P["black"] * np.stack([
        1.0 - 0.45 * blue_dom, np.ones_like(blue_dom), np.ones_like(blue_dom)
    ], axis=-1)
    rgb = black_floor + rgb * (P["white"] - black_floor)

    tau = 2.0 * np.pi
    centres = np.array([1.0, 3.0, 5.0], np.float32) / 6.0
    sub_coord = (u * sw) / P["subcells"]
    sub_phase = sub_coord % 1.0
    band = (np.floor(sub_phase * 3.0) + 0.5) / 3.0
    mask = 0.5 + 0.5 * np.cos(tau * (band[..., None] - centres))
    stripe_point = 1.0 + (2.0 * mask - 1.0) * P["subpixel"]

    sub_width = (sw / ow) / P["subcells"]
    cov = np.stack([
        periodic_box_coverage(sub_coord, sub_width, 0.0, 1.0 / 3.0),
        periodic_box_coverage(sub_coord, sub_width, 1.0 / 3.0, 2.0 / 3.0),
        periodic_box_coverage(sub_coord, sub_width, 2.0 / 3.0, 1.0),
    ], axis=-1)
    element_masks = np.array([[2.0, 0.5, 0.5],
                              [0.5, 2.0, 0.5],
                              [0.5, 0.5, 2.0]], np.float32)
    integrated_mask = cov @ element_masks
    stripe_integrated = 1.0 + (integrated_mask - 1.0) * P["subpixel"]
    element_pixels = (ow / sw) * P["subcells"] / 3.0
    misaligned = abs(element_pixels - round(element_pixels)) >= 1e-3
    stripe = stripe_integrated if misaligned else stripe_point

    if abs(ow / sw - 4.0) < 1e-3 and abs(P["subcells"] - 1.0) < 1e-3:
        qcov = np.stack([
            periodic_box_coverage(u * sw, sw / ow, 0.00, 0.30),
            periodic_box_coverage(u * sw, sw / ow, 0.30, 0.60),
            periodic_box_coverage(u * sw, sw / ow, 0.60, 0.90),
            periodic_box_coverage(u * sw, sw / ow, 0.90, 1.00),
        ], axis=-1)
        qmask = np.array([[2.0, 0.5, 0.5],
                          [0.5, 2.0, 0.5],
                          [0.5, 0.5, 2.0]], np.float32)
        active = 1.0 + (qmask - 1.0) * P["subpixel"]
        stripe = qcov[..., :3] @ active + qcov[..., 3:4] * (1.0 - P["aperture"])
    # Off by default: at the physical element pitch the imbalance is a three
    # pixel ripple, below what the eye separates into lines, and it is what
    # makes the elements visible rather than a flat wash.  Raise it only when
    # the triad is widened past one cell.
    if P["balance"] > 1e-4:
        lum_s = (stripe @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
        stripe = stripe * ((1.0 - P["balance"]) + P["balance"] / lum_s)

    if P["elemgap"] > 1e-3:
        ep = np.abs(((u * sw) * 3.0 / P["subcells"]) % 1.0 - 0.5) * 2.0
        stripe = stripe * ((1.0 - P["elemgap"] * ep * ep) /
                           (1.0 - P["elemgap"] / 3.0))[..., None]

    ex = np.abs(phase_x - 0.5) * 2.0
    ey = np.abs(phase_y - 0.5) * 2.0
    vertical_scale = oh / sh
    if abs(vertical_scale - round(vertical_scale)) >= 1e-3:
        ey2 = edge2_coverage(v * sh, sh / oh)
    else:
        ey2 = ey * ey
    grid = (1.0 - P["rowgap"] * ey2 - P["colgap"] * ex * ex) / (
        1.0 - (P["rowgap"] + P["colgap"]) / 3.0)

    # Keep the former field's min/max brightness; only its geometry changes.
    tube_light = 0.936 - 0.522 * edge_response
    back = 1.0 + (tube_light - 1.0) * P["backlight"]

    lamp = np.array([1.0, 1.0, 1.0], np.float32) + (
        np.array([0.90, 1.00, 0.94], np.float32) - 1.0) * P["tint"]

    out = rgb * stripe * grid[..., None] * lamp * back[..., None]
    out = 1.0 - np.exp(-P["bright"] * np.maximum(out, 0.0))
    return np.clip(out, 0.0, 1.0)


def optics(src, centre_weight=4.0, luma_mix=0.32, chroma_mix=1.0):
    """Final output-pixel crosstalk: colour spreads more than luminance."""
    total = centre_weight + 4.0
    spread = (centre_weight * src +
              np.roll(src, 1, axis=0) + np.roll(src, -1, axis=0) +
              np.roll(src, 1, axis=1) + np.roll(src, -1, axis=1)) / total
    luma_coeff = np.array([0.299, 0.587, 0.114], np.float32)
    centre_luma = src @ luma_coeff
    spread_luma = spread @ luma_coeff
    out_luma = centre_luma + (spread_luma - centre_luma) * luma_mix
    centre_chroma = src - centre_luma[..., None]
    spread_chroma = spread - spread_luma[..., None]
    out_chroma = centre_chroma + (spread_chroma - centre_chroma) * chroma_mix
    return np.clip(out_luma[..., None] + out_chroma, 0.0, 1.0)


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

    plain_43 = np.asarray(Image.fromarray((src * 255.0 + 0.5).astype(np.uint8)).resize(
        (OUT_W, OUT_H), Image.Resampling.NEAREST), np.float32) / 255.0
    plain_3x = np.repeat(np.repeat(src, 3, axis=0), 3, axis=1)
    to_panel(plain_43).save("%s/lcd-off.png" % out_dir)
    raw_panel = panel(src)
    to_panel(raw_panel).save("%s/lcd-panel-raw.png" % out_dir)
    to_panel(optics(raw_panel)).save("%s/lcd-on.png" % out_dir)
    to_panel(plain_3x).save("%s/lcd-off-integer3x.png" % out_dir)
    integer_panel = panel(src, INTEGER_W, INTEGER_H)
    to_panel(optics(integer_panel)).save(
        "%s/lcd-on-integer3x.png" % out_dir)

    # The response pass needs a history, so run a short motion sequence.
    seq = [moving_square(i) for i in range(12)]
    hist = [seq[-1 - i] for i in range(5)]
    to_panel(optics(panel(seq[-1]))).save("%s/lcd-motion-off.png" % out_dir)
    to_panel(optics(panel(response(hist)))).save("%s/lcd-motion-on.png" % out_dir)

    print("wrote 4:3 and integer3x LCD previews to", out_dir)


if __name__ == "__main__":
    main()
