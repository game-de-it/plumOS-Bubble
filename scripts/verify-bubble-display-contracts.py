#!/usr/bin/env python3
"""Validate logged Bubble viewport geometry from device-matrix reports."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path


PANEL_WIDTH = 640
PANEL_HEIGHT = 480
DRM_RE = re.compile(
    r"frame=(?P<fw>\d+)x(?P<fh>\d+) aspect=(?P<aspect>[0-9.]+) "
    r"rotation=(?P<rotation>[0-3]) viewport=(?P<vw>\d+)x(?P<vh>\d+)"
    r"\+(?P<x>\d+)\+(?P<y>\d+) scanout=(?P<sw>\d+)x(?P<sh>\d+)"
)
PYXEL_DISPLAY_RE = re.compile(r"source=(?P<fw>\d+)x(?P<fh>\d+)")
PYXEL_FIT_RE = re.compile(
    r"output=(?P<vw>\d+)x(?P<vh>\d+).*offset=(?P<x>[0-9.]+),(?P<y>[0-9.]+)"
)
FRAME_RE = re.compile(r"^(?P<width>\d+)x(?P<height>\d+)$")


def close_ratio(actual: float, expected: float) -> bool:
    return math.isclose(actual, expected, rel_tol=0.015, abs_tol=0.015)


def validate_drm(line: str) -> tuple[bool, str, bool]:
    match = DRM_RE.search(line)
    if not match:
        return False, "unparseable_retroarch_contract", False
    values = {key: float(value) for key, value in match.groupdict().items()}
    vw, vh = int(values["vw"]), int(values["vh"])
    x, y = int(values["x"]), int(values["y"])
    rotation = int(values["rotation"])
    expected = values["aspect"] if rotation % 2 == 0 else 1.0 / values["aspect"]
    checks = {
        "positive": vw > 0 and vh > 0,
        "bounded": x + vw <= PANEL_WIDTH and y + vh <= PANEL_HEIGHT,
        "centered": abs((PANEL_WIDTH - vw) - 2 * x) <= 2
        and abs((PANEL_HEIGHT - vh) - 2 * y) <= 2,
        "aspect": close_ratio(vw / vh, expected),
        "scanout": vw == int(values["sw"]) and vh == int(values["sh"]),
    }
    failed = [name for name, passed in checks.items() if not passed]
    return not failed, "ok" if not failed else ",".join(failed), rotation % 2 == 1


def validate_pyxel(lines: list[str]) -> tuple[bool, str]:
    display = next((PYXEL_DISPLAY_RE.search(line) for line in lines if "pyxel-display" in line), None)
    fit = next((PYXEL_FIT_RE.search(line) for line in lines if "pyxel-fit" in line), None)
    if not display or not fit:
        return False, "incomplete_pyxel_contract"
    fw, fh = int(display["fw"]), int(display["fh"])
    vw, vh = int(fit["vw"]), int(fit["vh"])
    x, y = float(fit["x"]), float(fit["y"])
    checks = {
        "positive": fw > 0 and fh > 0 and vw > 0 and vh > 0,
        "bounded": x + vw <= PANEL_WIDTH and y + vh <= PANEL_HEIGHT,
        "centered": abs((PANEL_WIDTH - vw) - 2 * x) <= 2
        and abs((PANEL_HEIGHT - vh) - 2 * y) <= 2,
        "aspect": close_ratio(vw / vh, fw / fh),
    }
    failed = [name for name, passed in checks.items() if not passed]
    return not failed, "ok" if not failed else ",".join(failed)


def validate_geometry_contract(contract: dict) -> tuple[bool, str, bool]:
    frame = FRAME_RE.match(str(contract.get("frame", "")))
    viewport = contract.get("expected_viewport") or {}
    try:
        fw, fh = int(frame["width"]), int(frame["height"])
        aspect = float(contract["effective_aspect"])
        vw, vh = int(viewport["width"]), int(viewport["height"])
        x, y = int(viewport["x"]), int(viewport["y"])
    except (KeyError, TypeError, ValueError):
        return False, "invalid_geometry_contract", False
    checks = {
        "positive": fw > 0 and fh > 0 and aspect > 0 and vw > 0 and vh > 0,
        "bounded": x >= 0 and y >= 0 and x + vw <= PANEL_WIDTH and y + vh <= PANEL_HEIGHT,
        "centered": abs((PANEL_WIDTH - vw) - 2 * x) <= 2
        and abs((PANEL_HEIGHT - vh) - 2 * y) <= 2,
        "aspect": close_ratio(vw / vh, aspect),
        "orientation": contract.get("orientation")
        == ("vertical" if aspect < 1.0 else "horizontal"),
    }
    failed = [name for name, passed in checks.items() if not passed]
    return not failed, "ok" if not failed else ",".join(failed), aspect < 1.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+", type=Path)
    args = parser.parse_args()
    results = []
    for report_path in args.reports:
        report = json.loads(report_path.read_text())
        for record in report["records"]:
            if record.get("status") != "started":
                continue
            lines = record.get("display_contract_lines", [])
            drm = next((line for line in lines if "Bubble display-contract" in line), None)
            if drm:
                passed, reason, vertical = validate_drm(drm)
                results.append((record["system"], record["profile"], "retroarch", passed, reason, vertical))
            elif any("plumos-pyxel-" in line for line in lines):
                passed, reason = validate_pyxel(lines)
                results.append((record["system"], record["profile"], "pyxel", passed, reason, False))
            elif record.get("geometry_contract"):
                passed, reason, vertical = validate_geometry_contract(record["geometry_contract"])
                results.append(
                    (record["system"], record["profile"], "expected_geometry", passed, reason, vertical)
                )
    failed = [result for result in results if not result[3]]
    vertical = [result for result in results if result[5]]
    print(
        f"bubble_display_contracts=result-{'fail' if failed else 'ok'} "
        f"observed={len(results)} pass={len(results) - len(failed)} "
        f"fail={len(failed)} vertical={len(vertical)}"
    )
    for system, profile, kind, passed, reason, is_vertical in results:
        if not passed or is_vertical:
            print(
                f"system={system} profile={profile} kind={kind} "
                f"result={'ok' if passed else 'fail'} reason={reason} vertical={'yes' if is_vertical else 'no'}"
            )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
