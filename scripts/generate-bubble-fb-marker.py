#!/usr/bin/env python3
"""Generate the fixed 640x480 XRGB8888 Bubble bring-up marker."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


FONT = {
    " ": (0, 0, 0, 0, 0, 0, 0),
    "0": (14, 17, 19, 21, 25, 17, 14), "1": (4, 12, 4, 4, 4, 4, 14),
    "2": (14, 17, 1, 2, 4, 8, 31), "3": (30, 1, 1, 14, 1, 1, 30),
    "4": (2, 6, 10, 18, 31, 2, 2), "5": (31, 16, 30, 1, 1, 17, 14),
    "6": (6, 8, 16, 30, 17, 17, 14), "7": (31, 1, 2, 4, 8, 8, 8),
    "8": (14, 17, 17, 14, 17, 17, 14), "9": (14, 17, 17, 15, 1, 2, 12),
    "A": (14, 17, 17, 31, 17, 17, 17), "B": (30, 17, 17, 30, 17, 17, 30),
    "C": (14, 17, 16, 16, 16, 17, 14), "D": (30, 17, 17, 17, 17, 17, 30),
    "E": (31, 16, 16, 30, 16, 16, 31), "F": (31, 16, 16, 30, 16, 16, 16),
    "G": (14, 17, 16, 23, 17, 17, 15), "H": (17, 17, 17, 31, 17, 17, 17),
    "I": (14, 4, 4, 4, 4, 4, 14), "J": (7, 2, 2, 2, 2, 18, 12),
    "K": (17, 18, 20, 24, 20, 18, 17), "L": (16, 16, 16, 16, 16, 16, 31),
    "M": (17, 27, 21, 21, 17, 17, 17), "N": (17, 25, 21, 19, 17, 17, 17),
    "O": (14, 17, 17, 17, 17, 17, 14), "P": (30, 17, 17, 30, 16, 16, 16),
    "Q": (14, 17, 17, 17, 21, 18, 13), "R": (30, 17, 17, 30, 20, 18, 17),
    "S": (15, 16, 16, 14, 1, 1, 30), "T": (31, 4, 4, 4, 4, 4, 4),
    "U": (17, 17, 17, 17, 17, 17, 14), "V": (17, 17, 17, 17, 17, 10, 4),
    "W": (17, 17, 17, 21, 21, 21, 10), "X": (17, 17, 10, 4, 10, 17, 17),
    "Y": (17, 17, 10, 4, 4, 4, 4), "Z": (31, 1, 2, 4, 8, 16, 31),
    "-": (0, 0, 0, 31, 0, 0, 0), ".": (0, 0, 0, 0, 0, 12, 12),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    width, height = 640, 480
    background = (52, 18, 86)
    accent = (92, 220, 138)
    white = (245, 245, 250)
    pixels = [background] * (width * height)

    def rect(x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int]) -> None:
        for y in range(max(0, y0), min(height, y1)):
            start = y * width + max(0, x0)
            end = y * width + min(width, x1)
            pixels[start:end] = [color] * (end - start)

    def text(value: str, x: int, y: int, scale: int, color: tuple[int, int, int]) -> None:
        for char in value:
            glyph = FONT[char]
            for row, bits in enumerate(glyph):
                for column in range(5):
                    if bits & (1 << (4 - column)):
                        rect(x + column * scale, y + row * scale,
                             x + (column + 1) * scale, y + (row + 1) * scale, color)
            x += 6 * scale

    rect(0, 0, width, 18, accent)
    rect(0, height - 18, width, height, accent)
    text("PLUMOS BUBBLE", 68, 92, 7, white)
    text("USERLAND REACHED", 50, 190, 6, accent)
    text("STAGE S33", 185, 280, 5, white)
    text("CHECK SD LOG", 155, 350, 4, white)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as handle:
        for red, green, blue in pixels:
            handle.write(struct.pack("<BBBB", blue, green, red, 0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
