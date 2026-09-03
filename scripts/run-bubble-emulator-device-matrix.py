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
INVALID_LIVE_CONTENT = {
    "ngp": "sd2_archive_read_failed_and_no_clean_monochrome_ngp_content",
    "pokemini": "no_valid_game_content_in_provided_mac_rom_set",
}
NO_CONTENT_ROUTES = {("2048", "retroarch:2048")}

CONTENT_OVERRIDES = {
    "sfc": f"{VALIDATION_CONTENT}/snes/Adventures of the Rocketeer.sfc",
    "gb": f"{VALIDATION_CONTENT}/gb/Baseball.gb",
    "gbc": f"{VALIDATION_CONTENT}/gbc/Cross Hunter - X Hunter Version.gbc",
    "gba": f"{VALIDATION_CONTENT}/gba/Densetsu no Stafy (Japan).gba",
    "pcenginecd": f"{SD2}/pcenginecd/AkumajouDraculaX.pcdGAME/AkumajouDraculaX.cue",
    "psx": f"{SD2}/PSX/2/SCPS-10026.cue",
    "saturn": f"{SD2}/SATURN/VH.iso",
    "msx": f"{VALIDATION_CONTENT}/msx/usas.rom",
    "pico8": f"{SD2}/pico-8/51752.p8",
    "pyxel": f"{VALIDATION_CONTENT}/pyxel/finardry.pyxapp",
    "psp": f"{VALIDATION_CONTENT}/psp/probe.cso",
    "nds": f"{VALIDATION_CONTENT}/nds/probe.nds",
    "n64": f"{VALIDATION_CONTENT}/n64/AeroGauge [V1.1].z64",
    "ngpc": f"{VALIDATION_CONTENT}/ngpc/probe.ngc",
    "fbneo": f"{VALIDATION_CONTENT}/fbneo/imgfight.zip",
    "mame2003plus": f"{VALIDATION_CONTENT}/mame2003plus/twinbee.zip",
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

MALI_RETROARCH_CORES = {
    "flycast", "flycast_xtreme", "km_duckswanstation_xtreme_amped",
    "mupen64plus_next", "parallel_n64", "yabasanshiro",
}
MALI_STANDALONES = {"yabasanshiro", "ppsspp", "openbor"}
GEOMETRY_RE = re.compile(
    r"(?:Geometry:|SET_SYSTEM_AV_INFO:)\s*(?P<width>\d+)x(?P<height>\d+), "
    r"Aspect:\s*(?P<aspect>[0-9.]+)"
)
ROTATION_RE = re.compile(r'SET_ROTATION:\s*"(?P<rotation>[0-3])"')


def renderer_expectation(profile: str) -> str:
    if profile.startswith("pyxel:"):
        return "mali_required"
    if profile.startswith("retroarch:") and profile.split(":", 1)[1] in MALI_RETROARCH_CORES:
        return "mali_required"
    if profile.startswith("standalone:") and profile.split(":", 1)[1] in MALI_STANDALONES:
        return "mali_required"
    if profile.startswith(("retroarch:", "picoarch:")):
        return "cpu_framebuffer_no_software_gl"
    return "route_owned_no_forced_software_gl"


def geometry_contract(runtime_log: str) -> dict | None:
    geometries = list(GEOMETRY_RE.finditer(runtime_log))
    if not geometries:
        return None
    match = geometries[-1]
    width = int(match["width"])
    height = int(match["height"])
    reported_aspect = float(match["aspect"])
    rotations = list(ROTATION_RE.finditer(runtime_log))
    rotation = int(rotations[-1]["rotation"]) if rotations else 0
    if reported_aspect > 0:
        aspect = reported_aspect
        aspect_source = "core_reported"
    else:
        aspect = width / height
        if rotation % 2:
            aspect = 1.0 / aspect
        aspect_source = "frame_geometry_with_rotation"
    panel_width, panel_height = 640, 480
    if aspect >= panel_width / panel_height:
        viewport_width = panel_width
        viewport_height = max(1, round(panel_width / aspect))
    else:
        viewport_height = panel_height
        viewport_width = max(1, round(panel_height * aspect))
    return {
        "frame": f"{width}x{height}",
        "reported_aspect": reported_aspect,
        "effective_aspect": round(aspect, 6),
        "aspect_source": aspect_source,
        "rotation_quadrants": rotation,
        "orientation": "vertical" if aspect < 1.0 else "horizontal",
        "expected_viewport": {
            "width": viewport_width,
            "height": viewport_height,
            "x": (panel_width - viewport_width) // 2,
            "y": (panel_height - viewport_height) // 2,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="192.168.10.101")
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-env", default="PLUMOS_SSH_PASSWORD")
    parser.add_argument("--library-index")
    parser.add_argument("--content-map", type=Path)
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
        self.exists_cache: dict[str, bool] = {}

    def run(self, command: str, *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [*self.base, command], input=input_text, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, errors="replace",
        )
        if check and result.returncode:
            raise RuntimeError(f"device command failed ({result.returncode}): {result.stderr.strip()}")
        return result

    def file(self, path: str) -> str:
        return self.run(f"cat {shlex.quote(path)}").stdout


def remote_exists(device: Device, path: str) -> bool:
    if path not in device.exists_cache:
        result = device.run(f"test -f {shlex.quote(path)}", check=False)
        if result.returncode == 255:
            result = device.run(f"test -f {shlex.quote(path)}", check=False)
        device.exists_cache[path] = result.returncode == 0
    return device.exists_cache[path]


def load_library(device: Device, path: str | None) -> dict:
    if path:
        return json.loads(Path(path).read_text())
    return json.loads(device.file(f"{ROOT}/state/frontend/library-index.json"))


def retroarch_config_contract(device: Device) -> dict:
    config = device.file(f"{ROOT}/config/retroarch/retroarch-bubble.cfg")
    keys = (
        "menu_driver", "video_driver", "video_aspect_ratio_auto",
        "video_force_aspect", "video_scale_integer", "video_rotation",
    )
    result = {}
    for key in keys:
        matches = re.findall(
            rf'^{re.escape(key)}\s*=\s*"([^"]*)"\s*$', config, re.MULTILINE
        )
        result[key] = matches[-1] if matches else None
    return result


def choose_content(
    system: dict, profile: str, live: dict, device: Device, content_map: dict[str, str]
) -> tuple[str | None, str]:
    sid = system["id"]
    route_key = f"{sid}|{profile}"
    mapped = content_map.get(route_key) or content_map.get(sid)
    if mapped:
        allowed_roots = (f"{VALIDATION_CONTENT}/", f"{SD2}/")
        if not mapped.startswith(allowed_roots):
            raise ValueError(f"content map path is outside validation roots: {route_key}: {mapped}")
        if remote_exists(device, mapped):
            source = "explicit_route_content_map" if route_key in content_map else "explicit_content_map"
            return mapped, source
        return None, "mapped_content_missing_on_device"
    override = CONTENT_OVERRIDES.get(sid)
    if override and remote_exists(device, override):
        return override, "explicit_validation_content" if override.startswith(ROOT) else "safe_live_override"
    if sid in INVALID_LIVE_CONTENT:
        return None, INVALID_LIVE_CONTENT[sid]
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
        if core == "bluemsx":
            env["PLUMOS_BIOS_ROOT"] = f"{ROOT}/share/libretro-system/bluemsx"
            prefix = " ".join(f"{key}={shlex.quote(value)}" for key, value in env.items())
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
            f"PLUMOS_ROOT={ROOT} PLUMOS_PYXEL_CPU_POLICY=performance /bin/busybox sh "
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
: > /run/plumos/validation/frontend-hold
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
    /bin/busybox setsid /bin/busybox sh "$R/bin/plumos-frontend-launch" \
        </dev/null >>"$R/logs/frontend-recovery.log" 2>&1 &
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
mali=""
software_gl=""
for p in /proc/[0-9]*; do
    test -d "$p/fd" || continue
    test "$(/bin/busybox awk '{print $5}' "$p/stat" 2>/dev/null)" = "$pid" || continue
    for f in "$p"/fd/*; do
        target=$(readlink "$f" 2>/dev/null || true)
        test "$target" = /dev/dri/card0 && drm="$drm${p##*/},"
        test "$target" = /dev/snd/pcmC0D0p && audio="$audio${p##*/},"
    done
    if test -r "$p/maps"; then
        grep -qi 'libmali' "$p/maps" 2>/dev/null && mali="$mali${p##*/},"
        grep -Eq 'kms_swrast|swrast_dri|libLLVM' "$p/maps" 2>/dev/null && software_gl="$software_gl${p##*/},"
    fi
done
pcm=$(sed -n 's/^state: //p' /proc/asound/card0/pcm0p/sub0/status 2>/dev/null || true)
pcm_states=${pcm:-closed}
pcm_progress=no
previous_hw=$(sed -n 's/^hw_ptr[[:space:]]*:[[:space:]]*//p' /proc/asound/card0/pcm0p/sub0/status 2>/dev/null || true)
sample=0
while test "$sample" -lt 8; do
    /bin/busybox usleep 250000
    sample_state=$(sed -n 's/^state: //p' /proc/asound/card0/pcm0p/sub0/status 2>/dev/null || true)
    sample_hw=$(sed -n 's/^hw_ptr[[:space:]]*:[[:space:]]*//p' /proc/asound/card0/pcm0p/sub0/status 2>/dev/null || true)
    pcm_states="$pcm_states,${sample_state:-closed}"
    if test -n "$previous_hw" && test -n "$sample_hw" && test "$sample_hw" != "$previous_hw"; then
        pcm_progress=yes
    fi
    previous_hw=$sample_hw
    sample=$((sample + 1))
done
remaining=$((SECONDS - probe - 2))
test "$remaining" -le 0 || sleep "$remaining"
if kill -0 "$pid" 2>/dev/null; then
    # Let the launcher trap TERM and reap its emulator child before escalating
    # to the whole process group. Killing both at once can orphan a zombie on
    # the stock BusyBox PID 1, which does not reliably reap adopted children.
    kill -TERM "$pid" 2>/dev/null || true
    n=0
    while kill -0 "$pid" 2>/dev/null && test "$n" -lt 50; do
        /bin/busybox usleep 100000
        n=$((n + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "-$pid" 2>/dev/null || true
        /bin/busybox sleep 1
        kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    fi
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
printf '__META__ alive=%s drm=%s audio=%s mali=%s software_gl=%s pcm=%s pcm_states=%s pcm_progress=%s rc=%s leftovers=%s preexisting=%s\n' "$alive" "${drm:-none}" "${audio:-none}" "${mali:-none}" "${software_gl:-none}" "${pcm:-closed}" "$pcm_states" "$pcm_progress" "$rc" "${left:-none}" "${preexisting:-none}"
printf '__RUNTIME_LOG__\n'
if test -f "$RLOG"; then tail -c +$((before + 1)) "$RLOG" | tail -120; fi
printf '__WRAPPER_LOG__\n'; tail -80 "$WRAP" 2>/dev/null || true
'''


def parse_meta(output: str) -> dict:
    line = next((line for line in output.splitlines() if line.startswith("__META__ ")), "")
    return dict(re.findall(
        r"(alive|drm|audio|mali|software_gl|pcm|pcm_states|pcm_progress|rc|leftovers|preexisting)=([^ ]*)",
        line,
    ))


def failure_reason(runtime_log: str, meta: dict, renderer_ok: bool, software_gl: bool) -> str:
    missing_crc = re.search(r"ROM index \d+ was not found .* CRC: (0x[0-9a-f]+)", runtime_log)
    if missing_crc:
        return f"content_load_missing_rom_crc_{missing_crc.group(1)}"
    if software_gl:
        return "software_gl_fallback_loaded"
    if not renderer_ok:
        return "required_mali_renderer_not_loaded"
    rc = meta.get("rc")
    if rc not in {None, "", "0", "137", "143"}:
        return f"route_exit_{rc}"
    if meta.get("alive") != "yes":
        return "route_not_alive_at_probe"
    if meta.get("drm") in {None, "", "none"}:
        return "route_did_not_own_drm"
    if meta.get("preexisting") not in {None, "", "none"}:
        return "preexisting_runtime_owner_detected"
    return "unclassified_route_failure"


def main() -> int:
    args = parse_args()
    password = os.environ.get(args.password_env)
    if not password:
        print(f"error: set {args.password_env}", file=sys.stderr)
        return 2
    device = Device(args.host, args.user, password)
    catalog = json.loads(CATALOG.read_text())
    live = load_library(device, args.library_index)
    content_map = {}
    if args.content_map:
        content_map = json.loads(args.content_map.read_text(encoding="utf-8"))
        if not isinstance(content_map, dict) or not all(
            isinstance(system_id, str) and isinstance(path, str)
            for system_id, path in content_map.items()
        ):
            raise ValueError("content map must be a JSON object of system ID to device path")
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    bios_root = VALIDATION_BIOS if device.run(
        f"test -d {shlex.quote(VALIDATION_BIOS)}", check=False
    ).returncode == 0 else f"{SD2}/BIOS"
    records = []
    for system in catalog["systems"]:
        if args.only_system and system["id"] not in args.only_system:
            continue
        for profile in system.get("launch_profiles", []):
            kind = profile.split(":", 1)[0]
            if args.only_kind and kind not in args.only_kind:
                continue
            content, content_source = choose_content(system, profile, live, device, content_map)
            command, log, seconds = route_command(system, profile, content or "", bios_root) if content else (None, None, 0)
            reason = None
            if not content:
                reason = (
                    "no_content_launch_not_implemented"
                    if (system["id"], profile) in NO_CONTENT_ROUTES
                    else content_source
                )
            elif profile.startswith("external:"):
                reason = "external_script_not_run_by_bounded_emulator_harness"
            elif system["id"] == "nds" and profile == "standalone:drastic":
                reason = "visible_unsupported_missing_miyooio_input_bridge"
            records.append({
                "system": system["id"], "profile": profile, "content": content,
                "content_source": content_source, "command": command, "runtime_log": log,
                "seconds": seconds,
                "renderer_expectation": renderer_expectation(profile),
                "status": (
                    "unsupported" if reason and reason.startswith("visible_unsupported_")
                    else "planned" if command and not reason else "not_run"
                ),
                "reason": reason,
            })
    report = {
        "schema": 1, "device": "GKD Bubble", "run_id": run_id,
        "catalog_systems": len(catalog["systems"]),
        "catalog_profile_occurrences": sum(len(s.get("launch_profiles", [])) for s in catalog["systems"]),
        "profile_filter": args.only_kind,
        "bios_root": bios_root,
        "retroarch_video_contract": retroarch_config_contract(device),
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
            wrapper_delta = output.split("__WRAPPER_LOG__\n", 1)[-1] if "__WRAPPER_LOG__\n" in output else ""
            display_lines = re.findall(
                r"(?:\[DRM\] )?Bubble (?:rotations|display-contract)[^\n]*|plumos-pyxel-(?:display|fit):[^\n]*",
                runtime_delta,
            )
            record.update({
                "ssh_rc": result.returncode, "probe": meta,
                "runtime_log_delta": runtime_delta[-16000:],
                "wrapper_log_delta": wrapper_delta[-8000:],
                "display_contract_lines": display_lines,
                "elapsed_seconds": round(time.monotonic() - started, 2),
                "geometry_contract": geometry_contract(runtime_delta),
            })
            alive = meta.get("alive") == "yes"
            drm = meta.get("drm") not in {None, "", "none"}
            clean = meta.get("preexisting") in {None, "", "none"}
            # 137/143 are expected when the bounded harness stops a healthy
            # route. A route that was alive at the early probe but then exits
            # with its own failure code must not be reported as started.
            bounded_exit = meta.get("rc") in {"0", "137", "143"}
            software_gl = (
                meta.get("software_gl") not in {None, "", "none"}
                or bool(re.search(r"(?:llvmpipe|softpipe|swrast)", runtime_delta, re.IGNORECASE))
            )
            mali = (
                meta.get("mali") not in {None, "", "none"}
                or bool(re.search(
                    r"(?:Renderer:\s*Mali|renderer(?: string)?:.*Mali|renderer-mali|"
                    r"ppsspp_affinity=render-cpu3|libmali)",
                    runtime_delta,
                    re.IGNORECASE,
                ))
            )
            renderer_ok = not software_gl and (
                record["renderer_expectation"] != "mali_required" or mali
            )
            record["renderer_contract"] = (
                "failed_software_gl_loaded" if software_gl
                else "failed_mali_not_loaded" if not renderer_ok
                else "mali_loaded" if mali
                else "no_software_gl_loaded"
            )
            record["renderer_warnings"] = (
                ["shader_link_failed"]
                if re.search(r"(?:thin3d \(failed\)|Could not link program)", runtime_delta)
                else []
            )
            record["status"] = (
                "started" if alive and drm and clean and bounded_exit and renderer_ok
                else "failed"
            )
            if record["status"] == "failed":
                record["reason"] = failure_reason(runtime_delta, meta, renderer_ok, software_gl)
            record["display_contract"] = "retroarch_drm" if any("Bubble display-contract" in line for line in display_lines) else "pyxel_fit" if any("plumos-pyxel-fit:" in line for line in display_lines) else "runtime_only"
            record["audio_contract"] = (
                "pcm_running_progress" if meta.get("pcm_progress") == "yes"
                else "pcm_running_observed" if "RUNNING" in meta.get("pcm_states", "").split(",")
                else "not_observed"
            )
            print(
                f"[{index:03d}/{len(planned):03d}] {record['system']} {record['profile']} "
                f"status={record['status']} drm={meta.get('drm','?')} pcm={meta.get('pcm','?')} "
                f"renderer={record['renderer_contract']}",
                flush=True,
            )
            out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    finally:
        device.run("/bin/sh -s", input_text=TEARDOWN, check=False)
    report["completed_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
    report["summary"] = {
        key: sum(r["status"] == key for r in records)
        for key in ("started", "failed", "unsupported", "not_run")
    }
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report["summary"], sort_keys=True), flush=True)
    return 1 if report["summary"]["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
