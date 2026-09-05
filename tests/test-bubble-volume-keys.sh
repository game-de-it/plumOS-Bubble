#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [ "${1:-}" != --inside ]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./tests/test-bubble-volume-keys.sh --inside
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
runtime=$tmp/run
mkdir -p "$root/bin" "$runtime/volume-keys"
gcc -std=gnu99 -Os -Wall -Wextra src/services/plumos_bubble_volume_keys.c \
    -o "$root/bin/plumos-volume-keys"
cat >"$root/bin/plumos-volume-control" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >>"${TEST_VOLUME_TRACE:?}"
EOF
chmod 0755 "$root/bin/plumos-volume-control"

python3 - "$tmp/up.events" <<'PY'
import struct
import sys
with open(sys.argv[1], "wb") as stream:
    stream.write(struct.pack("llHHi", 0, 0, 1, 115, 1))
    stream.write(struct.pack("llHHi", 0, 0, 1, 115, 0))
PY
TEST_VOLUME_TRACE=$tmp/up.trace PLUMOS_ROOT=$root \
PLUMOS_RUNTIME_ROOT=$runtime "$root/bin/plumos-volume-keys" \
    --event "$tmp/up.events" --once 2>"$tmp/up.log"
test "$(sed -n '1p' "$tmp/up.trace")" = apply
test "$(sed -n '2p' "$tmp/up.trace")" = runtime-up
test "$(sed -n '3p' "$tmp/up.trace")" = persist-runtime
grep -q 'action=volume direction=up rc=0' "$tmp/up.log"

python3 - "$tmp/down.events" <<'PY'
import struct
import sys
with open(sys.argv[1], "wb") as stream:
    stream.write(struct.pack("llHHi", 0, 0, 1, 114, 1))
    stream.write(struct.pack("llHHi", 0, 0, 1, 114, 0))
PY
TEST_VOLUME_TRACE=$tmp/down.trace PLUMOS_ROOT=$root \
PLUMOS_RUNTIME_ROOT=$runtime "$root/bin/plumos-volume-keys" \
    --event "$tmp/down.events" --once 2>"$tmp/down.log"
test "$(sed -n '2p' "$tmp/down.trace")" = runtime-down
grep -q 'action=volume direction=down rc=0' "$tmp/down.log"

printf 'bubble_volume_keys=result-ok input=gpio-keys codes=114,115\n'
