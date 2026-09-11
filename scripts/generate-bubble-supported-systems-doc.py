#!/usr/bin/env python3
"""Generate Bubble user-facing system, ROM directory, and emulator tables."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SYSTEMS = ROOT / "package/frontend-bubble/plumos/config/frontend/systems.json"
DEFAULT_JA_OUTPUT = ROOT / "docs/user/supported-systems.ja.md"
DEFAULT_EN_OUTPUT = ROOT / "docs/user/supported-systems.md"

ROUTE_LABELS = {
    "retroarch": "RA",
    "picoarch": "PICO",
    "standalone": "SA",
    "external": "External",
    "pyxel": "Pyxel",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--systems", type=Path, default=DEFAULT_SYSTEMS)
    parser.add_argument("--ja-output", type=Path, default=DEFAULT_JA_OUTPUT)
    parser.add_argument("--en-output", type=Path, default=DEFAULT_EN_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def code(value: str) -> str:
    return f"`{value}`"


def directories(system: dict) -> str:
    aliases = system.get("directory_aliases", [])
    if not aliases:
        return "—"
    return "<br>".join(code(f"Roms/{item['name']}/") for item in aliases)


def extensions(system: dict) -> str:
    values = system.get("extensions", [])
    return ", ".join(code(f".{value}") for value in values) if values else "—"


def launch_methods(system: dict, *, japanese: bool) -> str:
    default = system.get("default_launch_profile", "")
    grouped: dict[str, list[str]] = defaultdict(list)
    for profile in system.get("launch_profiles", []):
        route, separator, target = profile.partition(":")
        if not separator:
            route, target = "other", profile
        grouped[route].append(target)

    result: list[str] = []
    if default:
        route, _, target = default.partition(":")
        prefix = "既定" if japanese else "Default"
        result.append(f"**{prefix}:** {ROUTE_LABELS.get(route, route)} {code(target)}")
    for route, targets in grouped.items():
        remaining = [target for target in targets if f"{route}:{target}" != default]
        if remaining:
            result.append(
                f"{ROUTE_LABELS.get(route, route)}: "
                + ", ".join(code(target) for target in remaining)
            )
    return "<br>".join(result) if result else "—"


def render(data: dict, *, japanese: bool) -> str:
    systems = sorted(data.get("systems", []), key=lambda item: item.get("sort_order", 0))
    enabled = [system for system in systems if system.get("enabled", True)]
    disabled = [system for system in systems if not system.get("enabled", True)]

    if japanese:
        lines = [
            "# 対応システム・ROMフォルダ・拡張子・エミュレータ一覧",
            "",
            "この一覧は、GKD Bubble版plumOSのフロントエンドで現在有効なシステムを",
            "すべて掲載しています。ROMはSD1（本体上部のSYSスロット）またはSD2",
            "（本体下部のSD2スロット）の`Roms/`以下へ置きます。各行の最初のフォルダ名を",
            "推奨します。2つ目以降も別名として認識しますが、同じシステムのフォルダを複数",
            "作ると重複表示される場合があります。",
            "",
            "拡張子は大文字・小文字を区別しません。拡張子が認識されても、必要なBIOS、",
            "ROM set、ディスク構成、ゲーム固有の互換性によって起動できない場合があります。",
            "CD系は`.cue`、`.gdi`、`.m3u`など、トラック関係を保持できる形式を推奨します。",
            "",
            "起動方法の略称はRA=RetroArch、PICO=PicoArch、SA=Standaloneです。",
            "ゲーム選択中にSELECTを押すと、行に記載された別の起動方法を選べます。",
            "",
            f"## 対応システム（{len(enabled)}件）",
            "",
            "| システム | ROMフォルダ（先頭を推奨） | 対応拡張子 | 起動方法・エミュレータ／コア |",
            "| --- | --- | --- | --- |",
        ]
    else:
        lines = [
            "# Supported Systems, ROM Directories, Extensions, and Emulators",
            "",
            "This table lists every system currently enabled in plumOS for GKD Bubble.",
            "Place ROMs below `Roms/` on SD1 (the top SYS slot) or SD2 (the bottom SD2",
            "slot). The first directory is recommended. Other names are recognized aliases,",
            "but using multiple aliases for one system can create duplicate entries.",
            "",
            "Extensions are case-insensitive. Recognition does not guarantee compatibility:",
            "a correct BIOS, ROM set, disc layout, or game-specific support may still be",
            "required. Prefer `.cue`, `.gdi`, or `.m3u` where a disc has multiple files.",
            "",
            "RA means RetroArch, PICO means PicoArch, and SA means Standalone. Press SELECT",
            "on a game to choose another launch method listed in its row.",
            "",
            f"## Supported systems ({len(enabled)})",
            "",
            "| System | ROM directories (first recommended) | Extensions | Launch methods, emulators, and cores |",
            "| --- | --- | --- | --- |",
        ]

    for system in enabled:
        lines.append(
            "| "
            + " | ".join(
                (
                    system["display_name"],
                    directories(system),
                    extensions(system),
                    launch_methods(system, japanese=japanese),
                )
            )
            + " |"
        )

    if japanese:
        lines.extend([
            "", "## 現在無効なシステム", "",
            "次の項目は内部カタログに残っていますが、Bubbleでは対応済みとして公開せず、",
            "通常のTOP画面にも表示しません。3DSはRK3566の性能対象外のためカタログ自体から",
            "除外しています。Java MEは実機検証で利用可能なゲームを確認できなかったため無効です。",
            "", "| システム | 内部ID |", "| --- | --- |",
        ])
    else:
        lines.extend([
            "", "## Currently disabled systems", "",
            "These entries remain in the internal catalog but are not exposed as supported on",
            "Bubble. Nintendo 3DS is excluded from the catalog because it is outside the RK3566",
            "performance target. Java ME is disabled because device testing found no usable game.",
            "", "| System | Internal ID |", "| --- | --- |",
        ])
    for system in disabled:
        lines.append(f"| {system['display_name']} | {code(system['id'])} |")

    if japanese:
        lines.extend([
            "", "## 関連項目", "",
            "- [エミュレータとゲーム中の操作](emulators.ja.md)",
            "- [SDカードとフォルダ](storage.ja.md)",
            "- [BIOS、セーブ、スクリーンショット](save-data.ja.md)",
            "", "このファイルは`package/frontend-bubble/plumos/config/frontend/systems.json`を",
            "正として、`scripts/generate-bubble-supported-systems-doc.py`で生成します。",
        ])
    else:
        lines.extend([
            "", "## Related topics", "",
            "- [Emulators and in-game controls](emulators.md)",
            "- [SD cards and folders](storage.md)",
            "- [BIOS, saves, and screenshots](save-data.md)",
            "", "This file is generated from",
            "`package/frontend-bubble/plumos/config/frontend/systems.json` by",
            "`scripts/generate-bubble-supported-systems-doc.py`.",
        ])
    return "\n".join(lines) + "\n"


def update(path: Path, content: str, *, check: bool) -> bool:
    current = path.read_text(encoding="utf-8") if path.exists() else None
    if current == content:
        return True
    if check:
        print(f"stale generated documentation: {path}", file=sys.stderr)
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"wrote: {path}")
    return True


def main() -> int:
    args = parse_args()
    data = json.loads(args.systems.read_text(encoding="utf-8"))
    okay = update(args.ja_output, render(data, japanese=True), check=args.check)
    okay &= update(args.en_output, render(data, japanese=False), check=args.check)
    return 0 if okay else 1


if __name__ == "__main__":
    raise SystemExit(main())
