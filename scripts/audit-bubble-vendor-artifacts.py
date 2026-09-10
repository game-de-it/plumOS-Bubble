#!/usr/bin/env python3
"""Validate Bubble vendor provenance without importing ignored binaries."""

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "configs/bubble-vendor-artifacts.json"
ARTIFACT_ROOT = ROOT / "artifacts/vendor/bubble-stock-source"


def fail(reason: str) -> None:
    print(f"bubble_vendor_audit=result-fail reason={reason}", file=sys.stderr)
    raise SystemExit(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def expected_hashes(path: Path) -> dict[str, str]:
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        digest, relative = line.split(None, 1)
        result[relative.strip()] = digest
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-publishable", action="store_true")
    parser.add_argument("--policy", type=Path, default=POLICY)
    args = parser.parse_args()

    data = json.loads(args.policy.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or data.get("device") != "bubble":
        fail("policy-schema")
    inputs = data.get("inputs", [])
    if not inputs:
        fail("empty-input-list")

    ids = [item.get("id") for item in inputs]
    if None in ids or len(ids) != len(set(ids)):
        fail("input-id")
    for item in inputs:
        if not item.get("source_identity") and not item.get("source_url"):
            fail(f"missing-source-{item['id']}")
        if item.get("distribution_policy") not in {
            "redistributable", "public-with-vendor-notice",
            "project-approved-inclusion", "private-validation-only"
        }:
            fail(f"missing-policy-{item['id']}")

    approved_exceptions = {"drastic-closed-core"}
    for item in inputs:
        if (item["distribution_policy"] == "project-approved-inclusion"
                and item["id"] not in approved_exceptions):
            fail(f"unapproved-exception-{item['id']}")

    required_notices = [
        ROOT / "LICENSE",
        ROOT / "THIRD_PARTY_NOTICES.md",
        ROOT / "docs/licenses/GKD-stockOS-PERMISSION-NOTICE.txt",
        ROOT / "docs/licenses/bubble-vendor-runtime-NOTICE.txt",
        ROOT / "docs/licenses/drastic-upstream-NOTICE.txt",
        ROOT / "docs/licenses/bubble-runtime-license-inventory.tsv",
    ]
    if any(not path.is_file() or path.stat().st_size == 0
           for path in required_notices):
        fail("required-notice")

    tracked = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", str(ARTIFACT_ROOT)],
        check=True, text=True, capture_output=True
    ).stdout.strip()
    if tracked:
        fail("vendor-binary-tracked")

    checked = 0
    for item in inputs:
        manifest_name = item.get("hash_manifest")
        if not manifest_name:
            continue
        manifest = ROOT / manifest_name
        if not manifest.is_file():
            fail(f"missing-manifest-{item['id']}")
        if ARTIFACT_ROOT.is_dir():
            for relative, expected in expected_hashes(manifest).items():
                candidates = [ARTIFACT_ROOT / relative]
                if item["id"] == "bubble-stock-active-boot":
                    candidates += [ARTIFACT_ROOT / "boot" / relative]
                candidates += list(ARTIFACT_ROOT.rglob(Path(relative).name))
                local = list(dict.fromkeys(path for path in candidates if path.is_file()))
                if not local:
                    continue
                existing = next((path for path in local if sha256(path) == expected), None)
                if existing is None:
                    fail(f"hash-{item['id']}-{relative}")
                checked += 1

    for item in inputs:
        relative = item.get("path")
        if not relative:
            continue
        path = ARTIFACT_ROOT / relative
        if path.is_file():
            if path.stat().st_size != item["size"] or sha256(path) != item["sha256"]:
                fail(f"identity-{item['id']}")
            checked += 1

    private = [item["id"] for item in inputs
               if item["distribution_policy"] == "private-validation-only"]
    if args.require_publishable and private:
        fail("private-inputs-" + ",".join(private))
    print(
        "bubble_vendor_audit=result-ok "
        f"inputs={len(inputs)} checked_local={checked} "
        f"private_only={len(private)} publishable={int(not private)}"
    )


if __name__ == "__main__":
    main()
