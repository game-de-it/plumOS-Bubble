#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
builder=$repo_root/scripts/build-pyxel-bubble.sh
dockerfile=$repo_root/docker/bubble-tools/Dockerfile

grep -Eq 'python3-pip([[:space:]\\]|$)' "$dockerfile"
grep -Eq '([[:space:]\\])file([[:space:]\\]|$)' "$dockerfile"
grep -Fq 'find_target_lib libdl.so.2' "$builder"
grep -Fq 'install -m 0644 "$compat_path" "$PYXEL_LIB/libdl.so.2"' "$builder"
grep -Fq 'test -f "$PYXEL_LIB/libdl.so.2"' "$builder"
grep -Fq '"source_ref": "$source_ref"' "$builder"
grep -Fq 'PLUMOS_BUBBLE_PYTHON_LD_PRELOAD' "$builder"
if grep -Fq 'export LD_LIBRARY_PATH="$PYXEL_ROOT/lib:$PYTHON_ROOT/lib:/usr/lib"' "$builder"; then
    printf 'Bubble Pyxel launcher must not expose the glibc runtime to stock BusyBox\n' >&2
    exit 1
fi
if [ -d "$repo_root/output/pyxel/bubble/plumos" ]; then
    test -f "$repo_root/output/pyxel/bubble/plumos/apps/pyxel/lib/libdl.so.2"
    for library in \
        libbz2.so.1.0 libcrypto.so.3 liblzma.so.5 libreadline.so.8 \
        libsqlite3.so.0 libssl.so.3; do
        test -f "$repo_root/output/pyxel/bubble/plumos/apps/python/lib/$library"
    done
fi
printf 'bubble_pyxel_runtime=result-ok libdl=component-scoped\n'
