#!/usr/bin/env python3
"""Convert the shared 640x480 plumOS BMP into Bubble XRGB8888 fb0 bytes."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


WIDTH = 640
HEIGHT = 480


def convert(source: Path, output: Path) -> None:
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

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(xrgb)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    convert(args.source, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
