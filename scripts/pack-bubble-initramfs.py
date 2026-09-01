#!/usr/bin/env python3
"""Build a deterministic gzip-compressed newc archive without host cpio."""

from __future__ import annotations

import argparse
import gzip
import os
import stat
from pathlib import Path


def align4(value: int) -> int:
    return (value + 3) & ~3


def newc_header(mode: int, size: int, namesize: int, inode: int, mtime: int) -> bytes:
    fields = (
        inode,
        mode,
        0,
        0,
        2 if stat.S_ISDIR(mode) else 1,
        mtime,
        size,
        0,
        0,
        0,
        0,
        namesize,
        0,
    )
    return b"070701" + b"".join(f"{field:08x}".encode() for field in fields)


def append_entry(archive: bytearray, name: str, mode: int, data: bytes, inode: int, mtime: int) -> None:
    encoded_name = name.encode() + b"\0"
    archive.extend(newc_header(mode, len(data), len(encoded_name), inode, mtime))
    archive.extend(encoded_name)
    archive.extend(b"\0" * (align4(len(archive)) - len(archive)))
    archive.extend(data)
    archive.extend(b"\0" * (align4(len(archive)) - len(archive)))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--mtime", type=int, required=True)
    parser.add_argument("--uncompressed", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    paths = sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix())
    archive = bytearray()
    inode = 1
    for path in paths:
        relative = path.relative_to(root).as_posix()
        metadata = path.lstat()
        mode = metadata.st_mode
        if stat.S_ISREG(mode):
            data = path.read_bytes()
        elif stat.S_ISLNK(mode):
            data = os.readlink(path).encode()
        elif stat.S_ISDIR(mode):
            data = b""
        else:
            raise SystemExit(f"unsupported initramfs entry: {relative}")
        append_entry(archive, relative, mode, data, inode, args.mtime)
        inode += 1
    append_entry(archive, "TRAILER!!!", stat.S_IFREG, b"", inode, args.mtime)
    archive.extend(b"\0" * ((512 - len(archive) % 512) % 512))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.uncompressed:
        args.output.write_bytes(archive)
    else:
        with args.output.open("wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=args.mtime, compresslevel=9) as compressed:
                compressed.write(archive)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
