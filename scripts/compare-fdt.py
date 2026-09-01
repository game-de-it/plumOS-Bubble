#!/usr/bin/env python3
"""Compare two flattened device trees without requiring dtc."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


FDT_MAGIC = 0xD00DFEED
FDT_BEGIN_NODE = 1
FDT_END_NODE = 2
FDT_PROP = 3
FDT_NOP = 4
FDT_END = 9


def align4(value: int) -> int:
    return (value + 3) & ~3


def parse_fdt(path: Path) -> dict[tuple[str, str], bytes]:
    data = path.read_bytes()
    if len(data) < 40:
        raise ValueError(f"{path}: truncated FDT header")
    header = struct.unpack_from(">10I", data)
    magic, total_size, struct_off, strings_off = header[:4]
    strings_size = header[8]
    struct_size = header[9]
    if magic != FDT_MAGIC:
        raise ValueError(f"{path}: invalid FDT magic 0x{magic:08x}")
    if total_size > len(data):
        raise ValueError(f"{path}: declared size exceeds file size")
    strings = data[strings_off : strings_off + strings_size]
    cursor = struct_off
    struct_end = struct_off + struct_size
    stack: list[str] = []
    properties: dict[tuple[str, str], bytes] = {}

    while cursor + 4 <= struct_end:
        token = struct.unpack_from(">I", data, cursor)[0]
        cursor += 4
        if token == FDT_BEGIN_NODE:
            end = data.index(b"\0", cursor, struct_end)
            name = data[cursor:end].decode("utf-8", "surrogateescape")
            stack.append(name)
            cursor = align4(end + 1)
        elif token == FDT_END_NODE:
            if not stack:
                raise ValueError(f"{path}: unmatched FDT_END_NODE")
            stack.pop()
        elif token == FDT_PROP:
            length, name_off = struct.unpack_from(">II", data, cursor)
            cursor += 8
            name_end = strings.index(b"\0", name_off)
            name = strings[name_off:name_end].decode("utf-8", "surrogateescape")
            value = data[cursor : cursor + length]
            cursor = align4(cursor + length)
            node_path = "/" + "/".join(part for part in stack if part)
            properties[(node_path or "/", name)] = value
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            return properties
        else:
            raise ValueError(f"{path}: unknown token 0x{token:08x}")
    raise ValueError(f"{path}: missing FDT_END")


def format_value(value: bytes) -> str:
    if not value:
        return "<empty>"
    if value.endswith(b"\0"):
        parts = value[:-1].split(b"\0")
        if parts and all(part and all(32 <= byte < 127 for byte in part) for part in parts):
            return repr([part.decode("ascii") for part in parts])
    if len(value) <= 32 and len(value) % 4 == 0:
        cells = struct.unpack(f">{len(value) // 4}I", value)
        return "<" + " ".join(f"0x{cell:x}" for cell in cells) + ">"
    preview = value[:32].hex()
    suffix = "..." if len(value) > 32 else ""
    return f"bytes[{len(value)}]={preview}{suffix}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base", type=Path)
    parser.add_argument("runtime", type=Path)
    args = parser.parse_args()

    base = parse_fdt(args.base)
    runtime = parse_fdt(args.runtime)
    keys = sorted(set(base) | set(runtime))
    changed = 0
    for key in keys:
        before = base.get(key)
        after = runtime.get(key)
        if before == after:
            continue
        changed += 1
        path, name = key
        label = f"{path}:{name}"
        if before is None:
            print(f"ADDED {label} = {format_value(after or b'')}")
        elif after is None:
            print(f"REMOVED {label} = {format_value(before)}")
        else:
            print(f"CHANGED {label}")
            print(f"  base    {format_value(before)}")
            print(f"  runtime {format_value(after)}")
    print(f"summary base_properties={len(base)} runtime_properties={len(runtime)} changed={changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

