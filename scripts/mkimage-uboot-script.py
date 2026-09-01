#!/usr/bin/env python3
"""Build a deterministic U-Boot legacy script image without host mkimage."""

from __future__ import annotations

import argparse
import os
import struct
import zlib
from pathlib import Path


IH_MAGIC = 0x27051956
IH_OS_LINUX = 5
IH_ARCH_ARM = 2
IH_TYPE_SCRIPT = 6
IH_COMP_NONE = 0


def build_image(script: bytes, timestamp: int, name: str) -> bytes:
    encoded_name = name.encode("ascii")
    if len(encoded_name) > 32:
        raise ValueError("image name must be at most 32 ASCII bytes")
    payload = struct.pack(">II", len(script), 0) + script
    data_crc = zlib.crc32(payload) & 0xFFFFFFFF
    name_field = encoded_name.ljust(32, b"\0")
    header = struct.pack(
        ">7I4B32s",
        IH_MAGIC,
        0,
        timestamp,
        len(payload),
        0,
        0,
        data_crc,
        IH_OS_LINUX,
        IH_ARCH_ARM,
        IH_TYPE_SCRIPT,
        IH_COMP_NONE,
        name_field,
    )
    header_crc = zlib.crc32(header) & 0xFFFFFFFF
    header = header[:4] + struct.pack(">I", header_crc) + header[8:]
    return header + payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--name", default="")
    parser.add_argument(
        "--timestamp",
        type=int,
        default=int(os.environ.get("SOURCE_DATE_EPOCH", "0")),
    )
    args = parser.parse_args()
    image = build_image(args.input.read_bytes(), args.timestamp, args.name)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
