#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
builder=$repo_root/scripts/build-pyxel-bubble.sh
dockerfile=$repo_root/docker/bubble-tools/Dockerfile

grep -Eq 'python3-pip([[:space:]\\]|$)' "$dockerfile"
grep -Fq 'find_target_lib libdl.so.2' "$builder"
grep -Fq 'install -m 0644 "$compat_path" "$PYXEL_LIB/libdl.so.2"' "$builder"
grep -Fq 'test -f "$PYXEL_LIB/libdl.so.2"' "$builder"
if [ -d "$repo_root/output/pyxel/bubble/plumos" ]; then
    test -f "$repo_root/output/pyxel/bubble/plumos/apps/pyxel/lib/libdl.so.2"
fi
printf 'bubble_pyxel_runtime=result-ok libdl=component-scoped\n'
