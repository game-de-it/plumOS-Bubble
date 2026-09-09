#!/usr/bin/env python3
"""Fail when an unchecked Bubble TODO is anonymous, stale, or unclassified."""

import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TODO = ROOT / "TODO.md"
GATES = ROOT / "configs/bubble-todo-open-gates.json"
OPEN_RE = re.compile(r"^- \[ \] `([^`]+)`")
DONE_RE = re.compile(r"^- \[x\] `([^`]+)`")


def fail(message: str) -> None:
    print(f"bubble_todo_audit=result-fail reason={message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    lines = TODO.read_text(encoding="utf-8").splitlines()
    anonymous = [str(index) for index, line in enumerate(lines, 1)
                 if line.startswith("- [ ] ") and not OPEN_RE.match(line)]
    if anonymous:
        fail("anonymous-open-items-lines-" + ",".join(anonymous))

    open_ids = [match.group(1) for line in lines if (match := OPEN_RE.match(line))]
    done_ids = {match.group(1) for line in lines if (match := DONE_RE.match(line))}
    if len(open_ids) != len(set(open_ids)):
        fail("duplicate-open-id")

    data = json.loads(GATES.read_text(encoding="utf-8"))
    classified = data.get("open_gates", {})
    missing = sorted(set(open_ids) - set(classified))
    stale = sorted(set(classified) - set(open_ids))
    wrongly_done = sorted(set(classified) & done_ids)
    if missing:
        fail("unclassified-" + ",".join(missing))
    if stale:
        fail("stale-classification-" + ",".join(stale))
    if wrongly_done:
        fail("classified-as-open-but-done-" + ",".join(wrongly_done))

    counts = Counter(classified.values())
    summary = ",".join(f"{name}:{counts[name]}" for name in sorted(counts))
    print(f"bubble_todo_audit=result-ok open={len(open_ids)} classes={summary}")


if __name__ == "__main__":
    main()
