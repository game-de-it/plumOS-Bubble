#!/usr/bin/env python3
"""Load every source-record core and check the mandatory libretro ABI."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import sys


REQUIRED_SYMBOLS = (
    "retro_api_version",
    "retro_init",
    "retro_deinit",
    "retro_get_system_info",
    "retro_get_system_av_info",
    "retro_set_environment",
    "retro_set_video_refresh",
    "retro_set_audio_sample",
    "retro_set_audio_sample_batch",
    "retro_set_input_poll",
    "retro_set_input_state",
    "retro_load_game",
    "retro_unload_game",
    "retro_run",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()

    root = args.root.resolve()
    manifest_path = root / "components/libretro-cores/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = manifest.get("cores", [])
    if len(records) != 114:
        print(f"error: expected 114 source core records, found {len(records)}", file=sys.stderr)
        return 1

    failures: list[str] = []
    seen: set[str] = set()
    for record in records:
        core_id = record["id"]
        binary = record["binary"]
        if binary in seen:
            failures.append(f"{core_id}: duplicate primary binary {binary}")
            continue
        seen.add(binary)
        path = root / "cores" / binary
        try:
            library = ctypes.CDLL(
                os.fspath(path), mode=os.RTLD_NOW | os.RTLD_LOCAL
            )
            missing = [symbol for symbol in REQUIRED_SYMBOLS if not hasattr(library, symbol)]
            if missing:
                raise RuntimeError("missing symbols: " + ",".join(missing))
            library.retro_api_version.restype = ctypes.c_uint
            api_version = library.retro_api_version()
            if api_version != 1:
                raise RuntimeError(f"unexpected libretro API version {api_version}")
            print(f"core_load=result-ok id={core_id} binary={binary} api={api_version}")
        except (OSError, RuntimeError) as error:
            failures.append(f"{core_id}: {error}")

    if failures:
        for failure in failures:
            print(f"core_load=result-fail {failure}", file=sys.stderr)
        print(
            f"bubble_libretro_load_smoke=result-fail pass={len(records) - len(failures)} "
            f"fail={len(failures)}",
            file=sys.stderr,
        )
        return 1

    print(f"bubble_libretro_load_smoke=result-ok pass={len(records)} fail=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
