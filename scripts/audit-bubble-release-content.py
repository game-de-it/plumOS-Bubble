#!/usr/bin/env python3
"""Fail-closed source and app-layer publication audit for plumOS-Bubble."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


DEFAULT_ROOT = Path(__file__).resolve().parents[1]
ROM_SUFFIXES = {
    ".3ds", ".7z", ".chd", ".cia", ".cso", ".gb", ".gba", ".gbc",
    ".gg", ".iso", ".n64", ".nds", ".nes", ".pbp", ".sfc", ".smc",
    ".sms", ".v64", ".z64",
}
PRIVATE_KEY_MARKERS = (
    b"-----BEGIN OPENSSH PRIVATE KEY-----",
    b"-----BEGIN RSA PRIVATE KEY-----",
    b"-----BEGIN EC PRIVATE KEY-----",
    b"-----BEGIN PRIVATE KEY-----",
)
ALLOWED_APP_ARCHIVES = {
    "apps/portmaster/upstream/PortMaster/pylibs.zip",
    "share/libretro-system/scummvm/extra/helpdialog.zip",
    "share/libretro-system/scummvm/extra/vkeybd_default.zip",
    "share/libretro-system/scummvm/extra/wintermute.zip",
    "share/libretro-system/scummvm/theme/residualvm.zip",
    "share/libretro-system/scummvm/theme/scummclassic.zip",
    "share/libretro-system/scummvm/theme/scummmodern.zip",
    "share/libretro-system/scummvm/theme/scummremastered.zip",
}
ALLOWED_FIRMWARE_PREFIXES = (
    "share/libretro-system/bluemsx/Machines/MSX - C-BIOS/",
    "share/libretro-system/bluemsx/Machines/MSX2 - C-BIOS/",
    "share/libretro-system/bluemsx/Machines/MSX2+ - C-BIOS/",
)
ALLOWED_FIRMWARE = {
    "emulator/standalone/drastic/system/drastic_bios_arm7.bin",
    "emulator/standalone/drastic/system/drastic_bios_arm9.bin",
}


def fail(reason: str) -> None:
    print(f"bubble_release_content=result-fail reason={reason}", file=sys.stderr)
    raise SystemExit(1)


def run(*args: str, cwd: Path, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, check=False, text=True,
                          capture_output=capture)


def tracked_files(root: Path) -> list[Path]:
    result = run("git", "ls-files", "-z", cwd=root, capture=True)
    if result.returncode:
        fail("git-ls-files")
    return [root / item for item in result.stdout.split("\0") if item]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def audit_source(root: Path, require_clean: bool) -> int:
    if require_clean:
        for args in (("git", "diff", "--quiet", "HEAD", "--"),
                     ("git", "diff", "--cached", "--quiet", "HEAD", "--")):
            if run(*args, cwd=root).returncode:
                fail("tracked-checkout-dirty")

    count = 0
    for path in tracked_files(root):
        relative = path.relative_to(root).as_posix()
        suffix = path.suffix.lower()
        if suffix in ROM_SUFFIXES:
            fail("tracked-rom-" + relative)
        if not path.is_file() or path.is_symlink():
            continue
        count += 1
        if path.stat().st_size <= 8 * 1024 * 1024:
            data = path.read_bytes()
            if b"\0" not in data[:4096] and any(
                    marker in data for marker in PRIVATE_KEY_MARKERS):
                fail("tracked-private-key-" + relative)
    return count


def audit_app(root: Path, app: Path) -> tuple[int, int]:
    manifest_path = app / "manifest.json"
    if not manifest_path.is_file():
        fail("missing-app-manifest")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("publishable") is not True:
        fail("app-not-publishable")
    if manifest.get("user_media_included") is not False:
        fail("user-media-flag")
    if manifest.get("non_publishable_reasons") != []:
        fail("non-publishable-reasons")

    required = (
        "licenses/plumOS-MIT.txt",
        "licenses/THIRD_PARTY_NOTICES.md",
        "licenses/GKD-stockOS-PERMISSION-NOTICE.txt",
        "licenses/bubble-vendor-runtime-NOTICE.txt",
        "licenses/drastic-upstream-NOTICE.txt",
        "licenses/steward-fu-nds-LGPL-2.1",
        "licenses/drastic-upstream-release-readme.txt",
        "licenses/RUNTIME_LICENSE_INDEX.tsv",
    )
    for relative in required:
        if not (app / relative).is_file() or (app / relative).stat().st_size == 0:
            fail("missing-license-" + relative)

    for mutable in ("logs", "saves", "states"):
        directory = app / mutable
        if directory.is_dir() and any(path.is_file() for path in directory.rglob("*")):
            fail("mutable-data-" + mutable)

    files = 0
    firmware = 0
    for path in app.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(app).as_posix()
        files += 1
        parts = {part.lower() for part in path.relative_to(app).parts}
        if "roms" in parts or "bios" in parts:
            fail("user-media-path-" + relative)
        suffix = path.suffix.lower()
        approved_firmware = (relative in ALLOWED_FIRMWARE or
                             any(relative.startswith(prefix)
                                 for prefix in ALLOWED_FIRMWARE_PREFIXES))
        if suffix in ROM_SUFFIXES or suffix == ".rom":
            allowed = relative in ALLOWED_APP_ARCHIVES or approved_firmware
            if not allowed:
                fail("unapproved-content-" + relative)
        firmware += int(approved_firmware)
        if path.stat().st_size <= 8 * 1024 * 1024:
            data = path.read_bytes()
            if b"\0" not in data[:4096] and any(
                    marker in data for marker in PRIVATE_KEY_MARKERS):
                fail("app-private-key-" + relative)

    wifi = list(app.glob("config/**/wpa_supplicant.conf"))
    if wifi:
        fail("wifi-personalization")

    checksums = app / "checksums.sha256"
    if not checksums.is_file():
        fail("missing-global-checksum")
    for line in checksums.read_text(encoding="utf-8").splitlines():
        expected, relative = line.split(None, 1)
        target = app / relative.strip()
        if not target.is_file() or sha256(target) != expected:
            fail("checksum-" + relative.strip())

    audit = run(str(root / "scripts/audit-bubble-vendor-artifacts.py"),
                "--require-publishable", cwd=root)
    if audit.returncode:
        fail("vendor-license-gate")
    return files, firmware


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--app-root", type=Path)
    parser.add_argument("--require-clean-checkout", action="store_true")
    args = parser.parse_args()
    root = args.repo_root.resolve()
    app = (args.app_root or root / "output/app-layer/bubble/plumos").resolve()
    source_files = audit_source(root, args.require_clean_checkout)
    app_files, firmware = audit_app(root, app)
    print("bubble_release_content=result-ok "
          f"source_files={source_files} app_files={app_files} "
          f"approved_firmware={firmware} user_media=0 private_keys=0")


if __name__ == "__main__":
    main()
