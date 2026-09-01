#!/usr/bin/env python3
"""Inspect the hash-pinned initramfs embedded in the Bubble stock kernel."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import zlib


EXPECTED_IMAGE_SHA256 = "a6674c54976bf1bea36891bdb7f7a17c6f895437973adbda78fa7556570bfaab"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_newc(archive: bytes) -> dict[str, bytes]:
    entries: dict[str, bytes] = {}
    offset = 0
    while offset + 110 <= len(archive):
        header = archive[offset : offset + 110]
        if header[:6] != b"070701":
            raise ValueError(f"invalid newc magic at offset {offset}")
        fields = [int(header[6 + index * 8 : 14 + index * 8], 16) for index in range(13)]
        file_size = fields[6]
        name_size = fields[11]
        name_start = offset + 110
        name_end = name_start + name_size
        if name_size < 1 or name_end > len(archive):
            raise ValueError("invalid newc name size")
        raw_name = archive[name_start:name_end]
        if raw_name[-1:] != b"\0":
            raise ValueError("newc name is not terminated")
        name = raw_name[:-1].decode("utf-8")
        data_start = (name_end + 3) & ~3
        data_end = data_start + file_size
        if data_end > len(archive):
            raise ValueError("newc entry exceeds archive")
        if name == "TRAILER!!!":
            return entries
        entries[name] = archive[data_start:data_end]
        offset = (data_end + 3) & ~3
    raise ValueError("newc trailer is missing")


def embedded_archives(image: bytes):
    start = 0
    magic = b"\x1f\x8b\x08"
    while True:
        offset = image.find(magic, start)
        if offset < 0:
            return
        start = offset + 1
        decoder = zlib.decompressobj(16 + zlib.MAX_WBITS)
        try:
            archive = decoder.decompress(image[offset:]) + decoder.flush()
        except zlib.error:
            continue
        if not decoder.eof or not archive.startswith(b"070701"):
            continue
        compressed_size = len(image[offset:]) - len(decoder.unused_data)
        try:
            entries = parse_newc(archive)
        except ValueError:
            continue
        yield offset, compressed_size, archive, entries


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    args = parser.parse_args()

    image = args.image.read_bytes()
    image_sha = sha256(image)
    if image_sha != EXPECTED_IMAGE_SHA256:
        raise SystemExit(
            f"refusing unknown Image: expected {EXPECTED_IMAGE_SHA256}, got {image_sha}"
        )

    selected = None
    for candidate in embedded_archives(image):
        if "init" in candidate[3] and "functions" in candidate[3]:
            if selected is not None:
                raise SystemExit("multiple candidate initramfs archives found")
            selected = candidate
    if selected is None:
        raise SystemExit("embedded stock initramfs was not found")

    offset, compressed_size, archive, entries = selected
    init = entries["init"]
    functions = entries["functions"]
    required = {
        "system_image_argument": b"SYSTEM_IMAGE=*)",
        "flash_partition_fixed": b'mount_part "/dev/mmcblk1p1" "/flash"',
        "storage_partition_fixed": b'mount_part "/dev/mmcblk1p2" "/storage"',
    }
    for label, pattern in required.items():
        if pattern not in init:
            raise SystemExit(f"required stock initramfs boundary is missing: {label}")

    compressed = image[offset : offset + compressed_size]
    print("format=plumos-bubble-stock-initramfs-inspection-v1")
    print(f"image_sha256={image_sha}")
    print(f"gzip_offset={offset}")
    print(f"gzip_size={compressed_size}")
    print(f"gzip_sha256={sha256(compressed)}")
    print(f"cpio_size={len(archive)}")
    print(f"cpio_sha256={sha256(archive)}")
    print(f"entry_count={len(entries)}")
    print(f"init_size={len(init)}")
    print(f"init_sha256={sha256(init)}")
    print(f"functions_size={len(functions)}")
    print(f"functions_sha256={sha256(functions)}")
    print("system_image_argument=yes")
    print("flash_partition=/dev/mmcblk1p1")
    print("storage_partition=/dev/mmcblk1p2")
    print("external_initramfs_required_for_p3_runtime=yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
