#!/usr/bin/env python3
"""Summarize an opt-in Bubble frontend display trace."""

from __future__ import annotations

import argparse
import math
import re
import statistics
from pathlib import Path


FIELD = re.compile(r"(\w+)=([0-9]+)")


def percentile(values: list[int], fraction: float) -> int:
    ordered = sorted(values)
    return ordered[max(0, math.ceil(fraction * len(ordered)) - 1)]


def longest_active_run(rows: list[dict[str, int]]) -> list[dict[str, int]]:
    runs: list[list[dict[str, int]]] = []
    current: list[dict[str, int]] = []
    for row in rows[1:]:
        interval = row.get("interval_us", 0)
        if 0 < interval <= 50_000:
            current.append(row)
        else:
            if current:
                runs.append(current)
            current = []
    if current:
        runs.append(current)
    return max(runs, key=len) if runs else []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    rows = []
    for line in args.trace.read_text(encoding="utf-8").splitlines():
        row = {key: int(value) for key, value in FIELD.findall(line)}
        if "frame" in row:
            rows.append(row)
    if len(rows) < 2:
        raise SystemExit("error: trace contains fewer than two frames")

    latency = [
        row["input_to_present_us"]
        for row in rows
        if row.get("input_to_present_us", 0) > 0
    ]
    active = longest_active_run(rows)
    if not active or not latency:
        raise SystemExit("error: trace lacks an active frame run or input samples")
    intervals = [row["interval_us"] for row in active]
    one_vblank = sum(15_000 <= value <= 18_500 for value in intervals)
    two_vblank = sum(30_000 <= value <= 36_000 for value in intervals)
    other = len(intervals) - one_vblank - two_vblank
    one_vblank_values = [value for value in intervals if 15_000 <= value <= 18_500]
    refresh_hz = (
        1_000_000.0 / statistics.median(one_vblank_values)
        if one_vblank_values
        else 0.0
    )

    print(
        "bubble_display_trace=result-ok "
        f"frames={len(rows)} input_samples={len(latency)}"
    )
    print(
        "input_to_present_us="
        f"min:{min(latency)},median:{statistics.median(latency):.0f},"
        f"p95:{percentile(latency, 0.95)},max:{max(latency)}"
    )
    print(
        "active_pacing="
        f"frames:{len(intervals) + 1},duration_us:{sum(intervals)},"
        f"average_fps:{1_000_000.0 / statistics.mean(intervals):.3f},"
        f"interval_p95_us:{percentile(intervals, 0.95)},"
        f"interval_max_us:{max(intervals)},"
        f"one_vblank:{one_vblank},two_vblank:{two_vblank},other:{other}"
    )
    print(f"observed_vblank_hz={refresh_hz:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
