#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, *needles: str) -> str:
    target = ROOT / path
    assert target.is_file(), f"missing documentation: {path}"
    text = target.read_text(encoding="utf-8")
    for needle in needles:
        assert needle in text, f"{path}: missing {needle!r}"
    return text


def check_links(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    for raw in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        link = raw.split("#", 1)[0]
        if not link or "://" in link or link.startswith("mailto:"):
            continue
        target = (path.parent / link).resolve()
        assert target.exists(), f"{path.relative_to(ROOT)}: broken link {raw}"


def main() -> None:
    subprocess.run(
        ["python3", "scripts/generate-bubble-supported-systems-doc.py", "--check"],
        cwd=ROOT,
        check=True,
    )
    ja = require(
        "docs/user/README.ja.md",
        "SYSスロット",
        "本体上部",
        "SD2スロット",
        "本体下部",
        "Function 1（F1）",
        "本体前面",
        "Function 2（F2）",
    )
    en = require(
        "docs/user/README.md",
        "SYS slot",
        "Top edge",
        "SD2 slot",
        "Bottom edge",
        "Function 1 (F1)",
        "front face",
        "Function 2 (F2)",
    )
    require("docs/user/emulators.ja.md", "DraStic", "Function 2（本体上部）+`START`")
    require("docs/user/emulators.md", "DraStic", "Function 2 (top edge) + `START`")
    require("docs/user/supported-systems.ja.md", "## 対応システム（88件）", "3DS")
    require("docs/user/supported-systems.md", "## Supported systems (88)", "Nintendo 3DS")
    require(
        "docs/developer/README.ja.md",
        "SDカードがスロット外へ入り込んでいた",
        "cold boot 3回",
        "release判定を承認",
    )
    require(
        "docs/developer/README.md",
        "microSD card entering",
        "three",
        "cold boots",
        "accepted the result for release",
    )
    require(
        "docs/releases/0.1.0-rc1.md",
        "plumOS Bubble v0.1.0-rc1",
        "Known limitations",
        "既知の制限",
        "top-edge SYS slot",
        "本体上部のSYSスロット",
    )
    assert "hot plugは対応外" in ja
    assert "Hot-plugging SD2" in en
    curated = [
        ROOT / "README.ja.md",
        ROOT / "README.md",
        ROOT / "docs/README.ja.md",
        ROOT / "docs/README.md",
        *sorted((ROOT / "docs/user").glob("*.md")),
        *sorted((ROOT / "docs/developer").glob("*.md")),
    ]
    for path in curated:
        check_links(path)
    print("bubble_documentation=result-ok user_languages=2 supported_systems=88 links=ok")


if __name__ == "__main__":
    main()
