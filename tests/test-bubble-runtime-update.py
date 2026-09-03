#!/usr/bin/env python3
"""Exercise Bubble's signed Runtime update, health gate, and rollback."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


REPO = Path(__file__).resolve().parents[1]
BUILDER = REPO / "scripts/build-bubble-update-package.py"
UPDATER = REPO / "package/frontend-bubble/plumos/share/update/plumos-system-update.py"


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=True, text=True, capture_output=True, env=env)


def write_runtime(root: Path, version: str, payload: str, *, deleted_file: bool) -> None:
    (root / "bin").mkdir(parents=True)
    (root / "config/frontend").mkdir(parents=True)
    (root / "config/system").mkdir(parents=True)
    (root / "VERSION").write_text(f"{version}\n", encoding="ascii")
    (root / "COMPAT_VENDOR").write_text("bubble-stockos-r1\n", encoding="ascii")
    (root / "RUNTIME_ABI").write_text("1\n", encoding="ascii")
    (root / "bin/runtime-probe").write_text(f"{payload}\n", encoding="ascii")
    (root / "config/frontend/menus.json").write_text(
        json.dumps({"version": version}) + "\n", encoding="utf-8"
    )
    # This file is deliberately outside the managed update inventory.
    (root / "config/system/settings.json").write_text(
        '{"preserve":"user-setting"}\n', encoding="utf-8"
    )
    if deleted_file:
        (root / "bin/remove-on-update").write_text("old\n", encoding="ascii")


def build_package(
    input_root: Path,
    output_root: Path,
    key: Path,
    version: str,
    base_version: str,
    base_root: Path | None,
) -> Path:
    command = [
        str(BUILDER),
        "--type", "runtime",
        "--input", str(input_root),
        "--version", version,
        "--base-version", base_version,
        "--signing-key", str(key),
        "--output-dir", str(output_root),
    ]
    if base_root is not None:
        command.extend(["--base-dir", str(base_root)])
    run(command)
    return output_root / f"plumos-bubble-runtime-{version}.tar.gz"


def main() -> None:
    openssl = shutil.which("openssl")
    if not openssl:
        raise SystemExit("openssl is required")
    with tempfile.TemporaryDirectory(prefix="bubble-runtime-update-") as temp_name:
        temp = Path(temp_name)
        installed = temp / "installed"
        version_11 = temp / "runtime-1.1.0"
        version_12 = temp / "runtime-1.2.0"
        user_root = temp / "user"
        inbox = user_root / "updates"
        packages = temp / "packages"
        key = temp / "private.pem"
        public_key = temp / "public.pem"
        system_abi = temp / "system-abi"
        lock = temp / "update.lock"

        write_runtime(installed, "1.0.0", "runtime-one", deleted_file=True)
        write_runtime(version_11, "1.1.0", "runtime-two", deleted_file=False)
        write_runtime(version_12, "1.2.0", "runtime-three", deleted_file=False)
        inbox.mkdir(parents=True)
        packages.mkdir()
        system_abi.write_text("1\n", encoding="ascii")
        run([openssl, "genpkey", "-algorithm", "ED25519", "-out", str(key)])
        run([openssl, "pkey", "-in", str(key), "-pubout", "-out", str(public_key)])

        package_11 = build_package(
            version_11, packages, key, "1.1.0", "1.0.0", installed
        )
        inbox_11 = inbox / package_11.name
        shutil.copy2(package_11, inbox_11)

        env = os.environ.copy()
        env.update({
            "PLUMOS_ROOT": str(installed),
            "PLUMOS_USERDATA_ROOT": str(user_root),
            "PLUMOS_UPDATE_PUBLIC_KEY": str(public_key),
            "PLUMOS_UPDATE_OPENSSL": openssl,
            "PLUMOS_SYSTEM_ABI_FILE": str(system_abi),
            "PLUMOS_UPDATE_LOCK_FILE": str(lock),
            "PLUMOS_UPDATE_PROGRESS": "0",
            "PLUMOS_UPDATE_TMP": str(temp),
        })

        updater = [str(UPDATER)]
        scan = run(updater + ["scan"], env=env).stdout
        assert '"version": "1.1.0"' in scan
        request = run(updater + ["request-latest"], env=env).stdout
        assert "result=ready" in request
        run(updater + ["apply-pending"], env=env)
        assert (installed / "VERSION").read_text().strip() == "1.1.0"
        assert (installed / "bin/runtime-probe").read_text().strip() == "runtime-two"
        assert not (installed / "bin/remove-on-update").exists()
        assert (installed / "config/system/settings.json").read_text().strip() == (
            '{"preserve":"user-setting"}'
        )
        assert (installed / "update-state/runtime-pending.json").is_file()

        # A second boot without frontend readiness must restore the entire 1.0.0 set.
        run(updater + ["apply-pending"], env=env)
        assert (installed / "VERSION").read_text().strip() == "1.0.0"
        assert (installed / "bin/runtime-probe").read_text().strip() == "runtime-one"
        assert (installed / "bin/remove-on-update").read_text().strip() == "old"
        assert not (installed / "update-state/runtime-pending.json").exists()

        # Apply again and pass the same frontend-ready health gate used on-device.
        run(updater + ["request", str(inbox_11)], env=env)
        run(updater + ["apply-pending"], env=env)
        run(updater + ["mark-healthy"], env=env)
        assert (installed / "VERSION").read_text().strip() == "1.1.0"
        result = json.loads((installed / "update-state/last-result.json").read_text())
        assert result["result"] == "runtime_healthy"

        package_12 = build_package(
            version_12, packages, key, "1.2.0", "1.1.0", version_11
        )
        inbox_12 = inbox / package_12.name
        shutil.copy2(package_12, inbox_12)
        run(updater + ["request", str(inbox_12)], env=env)
        run(updater + ["apply-pending"], env=env)
        assert (installed / "bin/runtime-probe").read_text().strip() == "runtime-three"
        # Simulate another boot before health confirmation: it must return to 1.1.0.
        run(updater + ["apply-pending"], env=env)
        assert (installed / "VERSION").read_text().strip() == "1.1.0"
        assert (installed / "bin/runtime-probe").read_text().strip() == "runtime-two"
        assert (installed / "config/system/settings.json").read_text().strip() == (
            '{"preserve":"user-setting"}'
        )

        print("bubble_runtime_update=result-ok signature=ed25519 rollback=2 persistence=ok")


if __name__ == "__main__":
    main()
