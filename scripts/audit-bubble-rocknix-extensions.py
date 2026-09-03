#!/usr/bin/env python3
"""Audit Bubble's extension policy against a ROCKNIX distribution checkout."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


RE_NAME = re.compile(r'^SYSTEM_NAME="([^"]+)"', re.MULTILINE)
RE_EXTENSIONS = re.compile(r'^SYSTEM_EXTENSION="([^"]*)"', re.MULTILINE)


def load_rocknix(checkout: Path) -> dict[str, list[str]]:
    config_dir = checkout / "config" / "emulators"
    result: dict[str, list[str]] = {}
    for path in sorted(config_dir.glob("*.conf")):
        text = path.read_text(encoding="utf-8")
        name_match = RE_NAME.search(text)
        extensions_match = RE_EXTENSIONS.search(text)
        if not name_match or not extensions_match:
            continue
        extensions = []
        for raw in extensions_match.group(1).split():
            extension = raw.removeprefix(".").lower()
            if extension not in extensions:
                extensions.append(extension)
        result[name_match.group(1)] = extensions
    if not result:
        raise SystemExit(f"error: no ROCKNIX emulator configs found under {config_dir}")
    return result


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser()
    parser.add_argument("rocknix_checkout", type=Path)
    parser.add_argument(
        "--systems",
        type=Path,
        default=repo_root / "package/frontend-bubble/plumos/config/frontend/systems.json",
    )
    parser.add_argument(
        "--policy",
        type=Path,
        default=repo_root
        / "package/frontend-bubble/plumos/config/frontend/rocknix-extension-policy.json",
    )
    args = parser.parse_args()

    systems = json.loads(args.systems.read_text(encoding="utf-8"))["systems"]
    policy = json.loads(args.policy.read_text(encoding="utf-8"))
    rocknix = load_rocknix(args.rocknix_checkout)
    commit = subprocess.run(
        ["git", "-C", str(args.rocknix_checkout), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    canonical = json.dumps(
        {name: sorted(extensions) for name, extensions in sorted(rocknix.items())},
        sort_keys=True,
        separators=(",", ":"),
    ) + "\n"
    canonical_sha256 = hashlib.sha256(canonical.encode()).hexdigest()

    errors: list[str] = []
    reference = policy["reference"]
    if commit != reference["source_commit"]:
        errors.append(f"source commit: policy={reference['source_commit']} checkout={commit}")
    if len(rocknix) != reference["system_count"]:
        errors.append(
            f"source system count: policy={reference['system_count']} checkout={len(rocknix)}"
        )
    if canonical_sha256 != reference["canonical_sha256"]:
        errors.append(
            "source extension hash: "
            f"policy={reference['canonical_sha256']} checkout={canonical_sha256}"
        )

    catalog_ids = {system["id"] for system in systems}
    rules = {rule["system_id"]: rule for rule in policy["systems"]}
    if catalog_ids != set(rules):
        errors.append("catalog and policy system IDs differ")

    for system_id in sorted(catalog_ids & set(rules)):
        rule = rules[system_id]
        if rule["state"] != "mapped":
            continue
        missing_ids = [item for item in rule["rocknix_ids"] if item not in rocknix]
        if missing_ids:
            errors.append(f"{system_id}: missing ROCKNIX IDs {','.join(missing_ids)}")
            continue
        current = {
            extension
            for rocknix_id in rule["rocknix_ids"]
            for extension in rocknix[rocknix_id]
        }
        recorded = set(rule["reference_extensions"])
        if current != recorded:
            errors.append(
                f"{system_id}: added={','.join(sorted(current - recorded)) or '-'} "
                f"removed={','.join(sorted(recorded - current)) or '-'}"
            )

    if errors:
        for error in errors:
            print(f"error: {error}")
        return 1
    print(
        "bubble_rocknix_source_audit=result-ok "
        f"commit={commit[:7]} source_systems={len(rocknix)} bubble_systems={len(systems)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
