#!/usr/bin/env python3
"""Run a bounded, save-isolated Bubble launch-profile matrix over SSH."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time


REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "package/frontend-bubble/plumos/config/frontend/systems.json"
ROOT = "/storage/plumos"
SD2 = "/run/media/sd2"
VALIDATION_CONTENT = f"{ROOT}/state/device-matrix/content"
VALIDATION_BIOS = f"{ROOT}/state/device-matrix/bios"

CONTENT_OVERRIDES = {
    "pcenginecd": f"{SD2}/pcenginecd/AkumajouDraculaX.pcdGAME/AkumajouDraculaX.cue",
    "psx": f"{SD2}/PSX/2/SCPS-10026.cue",
    "saturn": f"{SD2}/SATURN/VH.iso",
    "msx": f"{SD2}/msx2/usas.rom",
    "pico8": f"{SD2}/pico-8/51752.p8",
    "pyxel": f"{VALIDATION_CONTENT}/pyxel/finardry.pyxapp",
    "psp": f"{VALIDATION_CONTENT}/psp/probe.cso",
    "nds": f"{VALIDATION_CONTENT}/nds/probe.nds",
    "ngpc": f"{VALIDATION_CONTENT}/ngpc/probe.ngc",
    "fbneo": f"{VALIDATION_CONTENT}/fbneo/probe.zip",
    "mame2003plus": f"{VALIDATION_CONTENT}/mame2003plus/probe-1942a.zip",
    "dos": f"{VALIDATION_CONTENT}/dos/probe.zip",
    "openbor": f"{VALIDATION_CONTENT}/openbor/probe.pak",
    "pc88": f"{VALIDATION_CONTENT}/pc88/probe.d88",
}

STANDALONE_LOGS = {
    "pcsx_rearmed": f"{ROOT}/logs/pcsx-rearmed-standalone.log",
    "yabasanshiro": f"{ROOT}/logs/yabasanshiro-standalone.log",
    "drastic": f"{ROOT}/logs/drastic-standalone.log",
    "ppsspp": f"{ROOT}/logs/ppsspp-standalone.log",
    "openbor": f"{ROOT}/logs/openbor-standalone.log",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="192.168.10.101")
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-env", default="PLUMOS_SSH_PASSWORD")
    parser.add_argument("--library-index")
    parser.add_argument("--report", default=str(REPO / "artifacts/device-validation/bubble-emulator-matrix.json"))
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--only-system", action="append", default=[])
    parser.add_argument("--only-kind", choices=("retroarch", "picoarch", "standalone", "pyxel"), action="append", default=[])
    return parser.parse_args()


class Device:
    def __init__(self, host: str, user: str, password: str):
        self.base = [
            "sshpass", "-p", password, "ssh", "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=8", f"{user}@{host}",
        ]

    def run(self, command: str, *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [*self.base, command], input=input_text, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        if check and result.returncode:
            raise RuntimeError(f"device command failed ({result.returncode}): {result.stderr.strip()}")
        return result

    def file(self, path: str) -> str:
        return self.run(f"cat {shlex.quote(path)}").stdout


def remote_exists(device: Device, path: str) -> bool:
    return device.run(f"test -f {shlex.quote(path)}", check=False).returncode == 0


def load_library(device: Device, path: str | None) -> dict:
    if path:
        return json.loads(Path(path).read_text())
    return json.loads(device.file(f"{ROOT}/state/frontend/library-index.json"))


def choose_content(system: dict, live: dict, device: Device) -> tuple[str | None, str]:
    sid = system["id"]
    override = CONTENT_OVERRIDES.get(sid)
    if override and remote_exists(device, override):
        return override, "explicit_validation_content" if override.startswith(ROOT) else "safe_live_override"
    live_system = next((s for s in live.get("systems", []) if s.get("id") == sid), None)
    if live_system:
        for rom in live_system.get("roms", []):
            path = rom.get("path")
            if path and remote_exists(device, path):
                return path, "live_library"
    return None, "no_compatible_content"


def route_command(system: dict, profile: str, content: str, bios_root: str) -> tuple[str | None, str | None, int]:
    sid = system["id"]
    root = VALIDATION_CONTENT if content.startswith(VALIDATION_CONTENT + "/") else SD2
    env = {
        "PLUMOS_ROOT": ROOT,
        "PLUMOS_ROM_ROOT": root,
        "PLUMOS_BIOS_ROOT": bios_root,
    }
    prefix = " ".join(f"{key}={shlex.quote(value)}" for key, value in env.items())
    if profile.startswith("retroarch:"):
        core = profile.split(":", 1)[1]
        command = (
            f"{prefix} /bin/busybox sh {ROOT}/bin/plumos-retroarch-launch "
            f"--system {shlex.quote(sid)} --core {ROOT}/cores/{shlex.quote(core)}_libretro.so "
            f"--rom {shlex.quote(content)} --cpu ondemand --safe-exit false"
        )
        log = f"{ROOT}/logs/retroarch-{sid}-{core}.log"
        seconds = 8 if core in {"flycast", "flycast_xtreme", "km_duckswanstation_xtreme_amped", "mupen64plus_next", "parallel_n64", "yabasanshiro"} else 5
        return command, log, seconds
    if profile.startswith("picoarch:"):
        core = profile.split(":", 1)[1]
        command = (
            f"{prefix} PLUMOS_PICOARCH_SYSTEM={shlex.quote(sid)} "
            f"PLUMOS_PICOARCH_CPU_POLICY=ondemand /bin/busybox sh "
            f"{ROOT}/bin/plumos-picoarch-launch {shlex.quote(core)} {shlex.quote(content)}"
        )
        return command, f"{ROOT}/logs/picoarch-{sid}-{core}.log", 5
    if profile.startswith("standalone:"):
        emulator = profile.split(":", 1)[1]
        command = (
            f"{prefix} PLUMOS_SDCARD_ROOT={SD2} PLUMOS_STANDALONE_CPU_POLICY=ondemand "
            f"/bin/busybox sh {ROOT}/bin/plumos-standalone-launch "
            f"{shlex.quote(emulator)} {shlex.quote(content)}"
        )
        return command, STANDALONE_LOGS.get(emulator, f"{ROOT}/logs/standalone-route.log"), 8
    if profile.startswith("pyxel:"):
        command = (
            f"PLUMOS_ROOT={ROOT} PLUMOS_PYXEL_CPU_POLICY=ondemand /bin/busybox sh "
            f"{ROOT}/bin/plumos-pyxel-bubble-launch -m pyxel play {shlex.quote(content)}"
        )
        return command, f"{ROOT}/logs/pyxel/runtime.log", 8
    return None, None, 0


SETUP = r'''
set -eu
R=/storage/plumos
RUN=$1
BASE=$R/state/device-matrix/$RUN
MOUNTS=/run/plumos/validation/matrix-mounts
mkdir -p /run/plumos/validation "$BASE/sandbox"
/bin/busybox sh "$R/bin/plumos-volume-control" apply 0
test "$(cat /run/plumos/volume/current)" = 0
for rel in config/retroarch config/standalone state/retroarch state/picoarch state/standalone state/pyxel-home saves states; do
    src=$BASE/sandbox/$rel
    dst=$R/$rel
    mkdir -p "$src" "$dst"
    case "$rel" in config/*) cp -a "$dst/." "$src/" 2>/dev/null || true ;; esac
done
: > "$MOUNTS"
for rel in config/retroarch config/standalone state/retroarch state/picoarch state/standalone state/pyxel-home saves states; do
    src=$BASE/sandbox/$rel
    dst=$R/$rel
    mount --bind "$src" "$dst"
    echo "$dst" >> "$MOUNTS"
done
for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null || true)
    case "$exe" in /storage/plumos/bin/plumos-controller-ui-*) kill -TERM "${p##*/}" ;; esac
done
sleep 2
'''

TEARDOWN = r'''
set -u
R=/storage/plumos
for p in /proc/[0-9]*; do
    for f in "$p"/fd/*; do
        test "$(readlink "$f" 2>/dev/null)" = /dev/dri/card0 || continue
        kill -TERM "${p##*/}" 2>/dev/null || true
        break
    done
done
sleep 1
for p in /proc/[0-9]*; do
    for f in "$p"/fd/*; do
        test "$(readlink "$f" 2>/dev/null)" = /dev/dri/card0 || continue
        kill -KILL "${p##*/}" 2>/dev/null || true
        break
    done
done
for dst in "$R/states" "$R/saves" "$R/state/pyxel-home" "$R/state/standalone" "$R/state/picoarch" "$R/state/retroarch" "$R/config/standalone" "$R/config/retroarch"; do
    umount "$dst" 2>/dev/null || true
done
rm -f /run/plumos/validation/frontend-hold /run/plumos/validation/matrix-mounts
/bin/busybox sh "$R/bin/plumos-volume-control" apply 0 >/dev/null 2>&1 || true
if ! /bin/busybox pidof plumos-controller-ui-fbdev >/dev/null 2>&1; then
    nohup /bin/busybox sh "$R/bin/plumos-frontend-launch" </dev/null >/dev/null 2>&1 &
fi
'''

RUN_ROUTE = r'''
set -u
R=/storage/plumos
CMD=$1
RLOG=$2
SECONDS=$3
WRAP=$4
before=0
test -f "$RLOG" && before=$(wc -c < "$RLOG")
/bin/busybox sh "$R/bin/plumos-volume-control" apply 0 >/dev/null 2>&1 || true
preexisting=""
for p in /proc/[0-9]*; do
    for f in "$p"/fd/*; do
        test "$(readlink "$f" 2>/dev/null)" = /dev/dri/card0 || continue
        preexisting="$preexisting${p##*/},"
        kill -KILL "${p##*/}" 2>/dev/null || true
        break
    done
done
/bin/busybox setsid /bin/busybox sh -c "$CMD" >"$WRAP" 2>&1 &
pid=$!
probe=4
test "$SECONDS" -lt "$probe" && probe=$SECONDS
sleep "$probe"
alive=no
kill -0 "$pid" 2>/dev/null && alive=yes
drm=""
audio=""
for p in /proc/[0-9]*; do
    test -d "$p/fd" || continue
    for f in "$p"/fd/*; do
        target=$(readlink "$f" 2>/dev/null || true)
        test "$target" = /dev/dri/card0 && drm="$drm${p##*/},"
        test "$target" = /dev/snd/pcmC0D0p && audio="$audio${p##*/},"
    done
done
pcm=$(sed -n 's/^state: //p' /proc/asound/card0/pcm0p/sub0/status 2>/dev/null || true)
remaining=$((SECONDS - probe))
test "$remaining" -le 0 || sleep "$remaining"
if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    n=0
    while kill -0 "$pid" 2>/dev/null && test "$n" -lt 50; do
        /bin/busybox usleep 100000
        n=$((n + 1))
    done
    kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
fi
wait "$pid" 2>/dev/null
rc=$?
left=""
for p in /proc/[0-9]*; do
    for f in "$p"/fd/*; do
        test "$(readlink "$f" 2>/dev/null)" = /dev/dri/card0 || continue
        left="$left${p##*/},"
        kill -TERM "${p##*/}" 2>/dev/null || true
        break
    done
done
sleep 1
for p in $(printf '%s' "$left" | /bin/busybox tr ',' ' '); do
    kill -KILL "$p" 2>/dev/null || true
done
printf '__META__ alive=%s drm=%s audio=%s pcm=%s rc=%s leftovers=%s preexisting=%s\n' "$alive" "${drm:-none}" "${audio:-none}" "${pcm:-closed}" "$rc" "${left:-none}" "${preexisting:-none}"
printf '__RUNTIME_LOG__\n'
if test -f "$RLOG"; then tail -c +$((before + 1)) "$RLOG" | tail -120; fi
printf '__WRAPPER_LOG__\n'; tail -80 "$WRAP" 2>/dev/null || true
'''


def parse_meta(output: str) -> dict:
    line = next((line for line in output.splitlines() if line.startswith("__META__ ")), "")
    return dict(re.findall(r"(alive|drm|audio|pcm|rc|leftovers|preexisting)=([^ ]*)", line))


def main() -> int:
    args = parse_args()
    password = os.environ.get(args.password_env)
    if not password:
        print(f"error: set {args.password_env}", file=sys.stderr)
        return 2
    device = Device(args.host, args.user, password)
    catalog = json.loads(CATALOG.read_text())
    live = load_library(device, args.library_index)
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    bios_root = VALIDATION_BIOS if device.run(
        f"test -d {shlex.quote(VALIDATION_BIOS)}", check=False
    ).returncode == 0 else f"{SD2}/BIOS"
    records = []
    for system in catalog["systems"]:
        if args.only_system and system["id"] not in args.only_system:
            continue
        content, content_source = choose_content(system, live, device)
        for profile in system.get("launch_profiles", []):
            kind = profile.split(":", 1)[0]
            if args.only_kind and kind not in args.only_kind:
                continue
            command, log, seconds = route_command(system, profile, content or "", bios_root) if content else (None, None, 0)
            reason = None
            if not content:
                reason = "no_compatible_content"
            elif profile.startswith("external:"):
                reason = "external_script_not_run_by_bounded_emulator_harness"
            records.append({
                "system": system["id"], "profile": profile, "content": content,
                "content_source": content_source, "command": command, "runtime_log": log,
                "seconds": seconds, "status": "planned" if command and not reason else "not_run",
                "reason": reason,
            })
    report = {
        "schema": 1, "device": "GKD Bubble", "run_id": run_id,
        "catalog_systems": len(catalog["systems"]),
        "catalog_profile_occurrences": sum(len(s.get("launch_profiles", [])) for s in catalog["systems"]),
        "profile_filter": args.only_kind,
        "bios_root": bios_root,
        "volume_requirement": {"persisted": 0, "runtime": 0, "softvol_raw": 0},
        "records": records,
    }
    out = Path(args.report)
    out.parent.mkdir(parents=True, exist_ok=True)
    if not args.execute:
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(f"planned={sum(r['status'] == 'planned' for r in records)} total={len(records)} report={out}")
        return 0

    planned = [r for r in records if r["status"] == "planned"]
    device.run(f"/bin/sh -s -- {shlex.quote(run_id)}", input_text=SETUP)
    try:
        for index, record in enumerate(planned, 1):
            safe_id = re.sub(r"[^A-Za-z0-9_.-]+", "_", f"{record['system']}-{record['profile']}")
            wrapper_log = f"{ROOT}/state/device-matrix/{run_id}/{safe_id}.wrapper.log"
            remote_command = "/bin/sh -s -- " + " ".join(shlex.quote(str(v)) for v in (
                record["command"], record["runtime_log"], record["seconds"], wrapper_log,
            ))
            started = time.monotonic()
            result = device.run(remote_command, input_text=RUN_ROUTE, check=False)
            output = result.stdout + ("\n" + result.stderr if result.stderr else "")
            meta = parse_meta(output)
            runtime_delta = output.split("__RUNTIME_LOG__\n", 1)[-1].split("__WRAPPER_LOG__\n", 1)[0] if "__RUNTIME_LOG__" in output else ""
            record.update({
                "ssh_rc": result.returncode, "probe": meta,
                "runtime_log_delta": runtime_delta[-16000:],
                "elapsed_seconds": round(time.monotonic() - started, 2),
            })
            alive = meta.get("alive") == "yes"
            drm = meta.get("drm") not in {None, "", "none"}
            clean = meta.get("preexisting") in {None, "", "none"}
            record["status"] = "started" if alive and drm and clean else "failed"
            record["display_contract"] = "retroarch_drm" if "Bubble display-contract" in runtime_delta else "pyxel_fit" if "plumos-pyxel-fit:" in runtime_delta else "runtime_only"
            print(f"[{index:03d}/{len(planned):03d}] {record['system']} {record['profile']} status={record['status']} drm={meta.get('drm','?')} pcm={meta.get('pcm','?')}", flush=True)
            out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    finally:
        device.run("/bin/sh -s", input_text=TEARDOWN, check=False)
    report["completed_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
    report["summary"] = {
        key: sum(r["status"] == key for r in records)
        for key in ("started", "failed", "not_run")
    }
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report["summary"], sort_keys=True), flush=True)
    return 1 if report["summary"]["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
