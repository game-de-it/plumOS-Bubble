#!/usr/bin/env python3
"""Convert the shared plumOS BMP into Bubble XRGB8888 boot visuals."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


WIDTH = 640
HEIGHT = 480
PANEL_Y = 336

FONT = {
    " ": ("00000",) * 7,
    "%": ("11001", "11010", "00100", "01000", "10110", "00110", "00000"),
    "/": ("00001", "00010", "00100", "01000", "10000", "00000", "00000"),
    "-": ("00000", "00000", "00000", "11111", "00000", "00000", "00000"),
    "0": ("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("01110", "10001", "00001", "00010", "00100", "01000", "11111"),
    "3": ("11110", "00001", "00001", "01110", "00001", "00001", "11110"),
    "4": ("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
    "5": ("11111", "10000", "10000", "11110", "00001", "00001", "11110"),
    "6": ("01110", "10000", "10000", "11110", "10001", "10001", "01110"),
    "7": ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
    "8": ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
    "9": ("01110", "10001", "10001", "01111", "00001", "00001", "01110"),
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "B": ("11110", "10001", "10001", "11110", "10001", "10001", "11110"),
    "C": ("01111", "10000", "10000", "10000", "10000", "10000", "01111"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "F": ("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
    "G": ("01111", "10000", "10000", "10111", "10001", "10001", "01111"),
    "H": ("10001", "10001", "10001", "11111", "10001", "10001", "10001"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "J": ("00111", "00010", "00010", "00010", "10010", "10010", "01100"),
    "K": ("10001", "10010", "10100", "11000", "10100", "10010", "10001"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "N": ("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "P": ("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
    "Q": ("01110", "10001", "10001", "10001", "10101", "10010", "01101"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "S": ("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
    "V": ("10001", "10001", "10001", "10001", "10001", "01010", "00100"),
    "W": ("10001", "10001", "10001", "10101", "10101", "10101", "01010"),
    "X": ("10001", "10001", "01010", "00100", "01010", "10001", "10001"),
    "Y": ("10001", "10001", "01010", "00100", "00100", "00100", "00100"),
    "Z": ("11111", "00001", "00010", "00100", "01000", "10000", "11111"),
}


def set_pixel(xrgb: bytearray, x: int, y: int, color: tuple[int, int, int]) -> None:
    if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
        return
    red, green, blue = color
    offset = (y * WIDTH + x) * 4
    xrgb[offset : offset + 4] = bytes((blue, green, red, 0))


def fill_rect(
    xrgb: bytearray, x: int, y: int, width: int, height: int,
    color: tuple[int, int, int],
) -> None:
    for py in range(y, y + height):
        for px in range(x, x + width):
            set_pixel(xrgb, px, py, color)


def draw_text(
    xrgb: bytearray, text: str, y: int, scale: int,
    color: tuple[int, int, int],
) -> None:
    text = text.upper()
    unsupported = sorted(set(text) - set(FONT))
    if unsupported:
        raise SystemExit(f"unsupported boot-progress glyphs: {unsupported}")
    glyph_width = 5 * scale
    spacing = scale
    total_width = len(text) * (glyph_width + spacing) - spacing
    x = (WIDTH - total_width) // 2
    for character in text:
        for row, bits in enumerate(FONT[character]):
            for column, bit in enumerate(bits):
                if bit == "1":
                    fill_rect(
                        xrgb, x + column * scale, y + row * scale,
                        scale, scale, color,
                    )
        x += glyph_width + spacing


def add_progress(xrgb: bytearray, message: str, percent: int, error: bool) -> None:
    if percent < 0 or percent > 100:
        raise SystemExit("progress percent must be in 0..100")
    accent = (224, 72, 88) if error else (141, 92, 246)
    fill_rect(xrgb, 48, PANEL_Y, 544, 124, (17, 20, 29))
    fill_rect(xrgb, 48, PANEL_Y, 544, 3, accent)
    draw_text(xrgb, message, PANEL_Y + 20, 3, (244, 244, 248))
    draw_text(xrgb, f"{percent}%", PANEL_Y + 53, 2, (196, 198, 210))
    fill_rect(xrgb, 80, PANEL_Y + 88, 480, 16, (48, 51, 64))
    fill_rect(xrgb, 84, PANEL_Y + 92, 472 * percent // 100, 8, accent)


def convert(
    source: Path, output: Path, message: str | None = None,
    percent: int = 0, error: bool = False, crop_y: int = 0,
) -> None:
    data = source.read_bytes()
    if len(data) < 54 or data[:2] != b"BM":
        raise SystemExit("input is not a Windows BMP")
    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    dib_size = struct.unpack_from("<I", data, 14)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    planes, bits_per_pixel = struct.unpack_from("<HH", data, 26)
    compression = struct.unpack_from("<I", data, 30)[0]
    if (
        dib_size != 40
        or width != WIDTH
        or height != HEIGHT
        or planes != 1
        or bits_per_pixel != 24
        or compression != 0
    ):
        raise SystemExit("expected uncompressed 640x480 24-bit Windows 3.x BMP")

    bmp_stride = ((width * 3 + 3) // 4) * 4
    required_size = pixel_offset + bmp_stride * height
    if len(data) != required_size:
        raise SystemExit("unexpected BMP payload size")

    xrgb = bytearray(width * height * 4)
    destination = 0
    for display_y in range(height):
        bmp_y = height - 1 - display_y
        source_offset = pixel_offset + bmp_y * bmp_stride
        for x in range(width):
            blue, green, red = data[source_offset + x * 3 : source_offset + x * 3 + 3]
            xrgb[destination : destination + 4] = bytes((blue, green, red, 0))
            destination += 4

    if message is not None:
        add_progress(xrgb, message, percent, error)
    if crop_y < 0 or crop_y >= HEIGHT:
        raise SystemExit("crop-y must be in 0..479")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(xrgb[crop_y * WIDTH * 4 :])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--message")
    parser.add_argument("--percent", type=int, default=0)
    parser.add_argument("--error", action="store_true")
    parser.add_argument("--crop-y", type=int, default=0)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.message is None and (args.percent != 0 or args.error):
        parser.error("--percent/--error require --message")
    convert(args.source, args.output, args.message, args.percent, args.error, args.crop_y)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
