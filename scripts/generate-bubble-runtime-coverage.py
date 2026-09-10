#!/usr/bin/env python3
"""Generate Bubble's per-route runtime coverage from packaged artifacts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def read_info(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    if not path.is_file():
        return result
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" not in raw or raw.lstrip().startswith("#"):
            continue
        key, value = raw.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] == '"':
            value = value[1:-1]
        result[key.strip()] = value
    return result


def as_bool(value: str) -> bool:
    return value.lower() in {"true", "serialized", "deterministic", "basic"}


def firmware(info: dict[str, str]) -> dict:
    files = []
    for index in range(int(info.get("firmware_count", "0") or "0")):
        path = info.get(f"firmware{index}_path", "")
        optional = info.get(f"firmware{index}_opt", "true").lower() == "true"
        if path:
            files.append({
                "path": path,
                "description": info.get(f"firmware{index}_desc", path),
                "optional": optional,
            })
    explicit_policy = info.get("firmware_policy", "")
    if explicit_policy:
        policy = explicit_policy
    elif not files:
        policy = "none"
    elif any(not item["optional"] for item in files):
        policy = "required"
    else:
        policy = "optional"
    return {"root": "user:BIOS", "policy": policy, "files": files}


def first_existing(app_root: Path, candidates: list[str]) -> str:
    for candidate in candidates:
        if (app_root / candidate).is_file():
            return candidate
    return ""


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--systems", type=Path,
                        default=repo / "package/frontend-bubble/plumos/config/frontend/systems.json")
    parser.add_argument("--app-root", type=Path,
                        default=repo / "output/app-layer/bubble/plumos")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    systems_doc = read_json(args.systems)
    app_root = args.app_root
    core_doc = read_json(app_root / "components/libretro-cores/manifest.json")
    standalone_doc = read_json(app_root / "components/standalone/manifest.json")

    core_by_route: dict[str, dict] = {}
    for core in core_doc["cores"]:
        names = [core["binary"], *core.get("binary_aliases", [])]
        for name in names:
            if name.endswith("_libretro.so"):
                core_by_route[name.removesuffix("_libretro.so")] = core
    standalone = {entry["id"]: entry for entry in standalone_doc["emulators"]}

    ownership = {
        "retroarch": {
            "loader": "bin/plumos-retroarch-launch",
            "library_roots": ["emulator/lib"],
            "bios_root": "user:BIOS",
            "save_root": "saves",
            "state_root": "states",
            "owner": "device-user",
        },
        "picoarch": {
            "loader": "bin/plumos-picoarch-launch",
            "library_roots": ["picoarch/lib", "emulator/lib"],
            "bios_root": "user:BIOS",
            "save_root": "saves/<system_id>",
            "state_root": "state/picoarch/<system_id>",
            "owner": "device-user",
        },
        "standalone": {
            "loader": "bin/plumos-standalone-launch",
            "library_roots": ["emulator/lib", "emulator/standalone/<runtime>/lib"],
            "bios_root": "user:BIOS",
            "save_root": "state/standalone/<runtime>",
            "state_root": "state/standalone/<runtime>",
            "owner": "device-user",
        },
        "pyxel": {
            "loader": "bin/plumos-pyxel-bubble-launch",
            "library_roots": ["apps/pyxel/lib", "apps/python/lib", "emulator/lib"],
            "bios_root": None,
            "save_root": "state/pyxel",
            "state_root": "state/pyxel",
            "owner": "device-user-and-application",
        },
        "external": {
            "loader": "bin/plumos-portmaster-port-launch",
            "library_roots": ["state/portmaster/runtime/lib", "emulator/lib", "apps/pyxel/lib"],
            "bios_root": None,
            "save_root": "state/portmaster/data",
            "state_root": "state/portmaster",
            "owner": "port-and-device-user",
        },
    }

    standalone_license = {
        "pcsx_rearmed": "licenses/pcsx-rearmed-standalone-COPYING",
        "yabasanshiro": "licenses/yabasanshiro-LICENSE",
        "drastic": "licenses/drastic-upstream-NOTICE.txt",
        "ppsspp": "licenses/ppsspp-LICENSE.txt",
        "openbor": "licenses/openbor-LICENSE",
    }
    standalone_bios = {
        "pcsx_rearmed": {"root": "user:BIOS", "policy": "optional", "files": [{"path": "*.bin", "description": "PlayStation BIOS", "optional": True}]},
        "yabasanshiro": {"root": "user:BIOS", "policy": "optional", "files": [{"path": "saturn_bios.bin|sega_101.bin|mpr-17933.bin|saturn/mpr-17933.bin", "description": "Saturn BIOS search order", "optional": True}]},
        "drastic": {"root": "component-and-user", "policy": "packaged-with-user-override", "files": []},
        "ppsspp": {"root": None, "policy": "none", "files": []},
        "openbor": {"root": None, "policy": "none", "files": []},
    }

    covered_systems = []
    route_count = 0
    for system in systems_doc["systems"]:
        routes = []
        for profile in system["launch_profiles"]:
            runtime, route_id = profile.split(":", 1)
            route_count += 1
            route = {
                "profile": profile,
                "runtime": runtime,
                "runtime_id": route_id,
                "ownership_policy": runtime,
                "content_extensions": system["extensions"],
            }
            if runtime in {"retroarch", "picoarch"}:
                core = core_by_route.get(route_id)
                if core is None:
                    raise SystemExit(f"unresolved core metadata: {profile}")
                source_id = core["id"]
                info = read_info(app_root / f"info/{route_id}_libretro.info")
                if not info:
                    info = read_info(app_root / f"info/{source_id}_libretro.info")
                license_path = first_existing(app_root, [
                    f"licenses/{route_id}-LICENSE",
                    f"licenses/{source_id}-LICENSE",
                ])
                route.update({
                    "source_core_id": source_id,
                    "binary": f"cores/{route_id}_libretro.so",
                    "renderer": core["rendering"] if runtime == "retroarch" else "software-cpu-drm",
                    "bios": firmware(info),
                    "core_supported_extensions": [item for item in info.get("supported_extensions", "").split("|") if item],
                    "license": {"declared": info.get("license", "unknown"), "status": "packaged" if license_path else "missing", "path": license_path},
                    "save_supported": as_bool(info.get("libretro_saves", "false")),
                    "state_supported": as_bool(info.get("savestate", "false")),
                })
            elif runtime == "standalone":
                emulator = standalone.get(route_id)
                if emulator is None:
                    raise SystemExit(f"unresolved standalone metadata: {profile}")
                license_path = standalone_license[route_id]
                route.update({
                    "binary": emulator["binary"],
                    "renderer": emulator["renderer"],
                    "bios": standalone_bios[route_id],
                    "license": {"declared": "DraStic-separate" if route_id == "drastic" else "see-packaged-evidence", "status": "project-approved-inclusion" if route_id == "drastic" else "packaged", "path": license_path},
                    "save_supported": True,
                    "state_supported": route_id != "openbor",
                })
            elif runtime == "pyxel":
                route.update({
                    "binary": "apps/python/bin/python3.11",
                    "renderer": "mali-g52-sdl2-kmsdrm-gles2",
                    "bios": {"root": None, "policy": "none", "files": []},
                    "license": {"declared": "MIT", "status": "packaged", "path": "apps/pyxel/site/pyxel/LICENSE"},
                    "save_supported": True,
                    "state_supported": False,
                })
            elif runtime == "external":
                route.update({
                    "binary": "bin/plumos-portmaster-port-launch",
                    "renderer": "port-owned-canonical-mali-or-cpu",
                    "bios": {"root": None, "policy": "port-specific", "files": []},
                    "license": {"declared": "per-port", "status": "runtime-managed", "path": "apps/portmaster/upstream/PortMaster/licenses"},
                    "save_supported": True,
                    "state_supported": "port-specific",
                })
            else:
                raise SystemExit(f"unknown runtime: {profile}")
            routes.append(route)

        covered_systems.append({
            "system_id": system["id"],
            "directory_aliases": system["directory_aliases"],
            "extensions": system["extensions"],
            "default_launch_profile": system["default_launch_profile"],
            "support": system.get("support", {"state": "supported"}),
            "routes": routes,
        })

    document = {
        "version": 2,
        "device": "bubble",
        "generated_from": {
            "systems": "config/frontend/systems.json",
            "libretro_manifest": "components/libretro-cores/manifest.json",
            "standalone_manifest": "components/standalone/manifest.json",
            "core_info": "info/*_libretro.info",
        },
        "catalog": {
            "systems": len(covered_systems),
            "launch_profile_occurrences": route_count,
            "source_libretro_cores": len(core_doc["cores"]),
        },
        "ownership_policies": ownership,
        "systems": covered_systems,
        "release_complete": False,
        "release_blockers": ["BUB-P7-05", "BUB-P7-06", "BUB-P7-07", "BUB-P7-08"],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
