#!/usr/bin/env python3
"""Merge Bubble matrix reports, with later retests superseding earlier rows."""

from __future__ import annotations

import argparse
from collections import Counter
import datetime as dt
import json
from pathlib import Path
import re


def infer_failure_reason(record: dict) -> str:
    runtime_log = record.get("runtime_log_delta") or ""
    missing_crc = re.search(r"ROM index \d+ was not found .* CRC: (0x[0-9a-f]+)", runtime_log)
    if missing_crc:
        return f"content_load_missing_rom_crc_{missing_crc.group(1)}"
    rc = (record.get("probe") or {}).get("rc")
    if rc not in {None, "", "0", "137", "143"}:
        return f"route_exit_{rc}"
    return "unclassified_route_failure"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sources = []
    records: dict[tuple[str, str], dict] = {}
    order: list[tuple[str, str]] = []
    baseline = None

    for path in args.reports:
        report = json.loads(path.read_text())
        if baseline is None:
            baseline = report
        sources.append(
            {
                "path": str(path),
                "run_id": report.get("run_id"),
                "summary": report.get("summary"),
            }
        )
        seen: set[tuple[str, str]] = set()
        for record in report["records"]:
            key = (record["system"], record["profile"])
            if key in seen:
                raise ValueError(f"duplicate route in {path}: {key}")
            seen.add(key)
            if key not in records:
                order.append(key)
            if key == ("2048", "retroarch:2048") and record.get("status") == "not_run":
                record["reason"] = "no_content_launch_not_implemented"
            if record.get("status") == "failed" and not record.get("reason"):
                record["reason"] = infer_failure_reason(record)
            records[key] = record

    assert baseline is not None
    merged_records = [records[key] for key in order]
    status = Counter(record["status"] for record in merged_records)
    started = [record for record in merged_records if record["status"] == "started"]
    renderer = Counter(record.get("renderer_contract", "not_recorded") for record in started)
    audio = Counter(record.get("audio_contract", "not_recorded") for record in started)
    geometry = Counter(
        (record.get("geometry_contract") or {}).get("orientation", "not_recorded")
        for record in started
    )

    expected = baseline.get("catalog_profile_occurrences")
    if expected is not None and len(merged_records) != expected:
        raise ValueError(
            f"merged route count {len(merged_records)} does not match catalog {expected}"
        )

    output = {
        "schema": 1,
        "device": baseline.get("device"),
        "merge_policy": "later report supersedes earlier record by system and profile",
        "source_reports": sources,
        "catalog_systems": baseline.get("catalog_systems"),
        "catalog_profile_occurrences": expected,
        "retroarch_video_contract": baseline.get("retroarch_video_contract"),
        "volume_requirement": baseline.get("volume_requirement"),
        "records": merged_records,
        "completed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "summary": dict(sorted(status.items())),
        "started_contracts": {
            "renderer": dict(sorted(renderer.items())),
            "audio": dict(sorted(audio.items())),
            "geometry": dict(sorted(geometry.items())),
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(output["summary"], ensure_ascii=False, sort_keys=True))
    print(json.dumps(output["started_contracts"], ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
