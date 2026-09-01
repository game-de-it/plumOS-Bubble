#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/plumos-bubble-probe-test.XXXXXX")
cleanup() {
    case "$test_dir" in
        "${TMPDIR:-/tmp}"/plumos-bubble-probe-test.*)
            find "$test_dir" -depth -delete
            ;;
    esac
}
trap cleanup EXIT HUP INT TERM

/bin/sh -n \
    "$repo_root/probe/bin/plumos-boot-probe-log" \
    "$repo_root/probe/bin/plumos-boot-probe-snapshot" \
    "$repo_root/scripts/clone-bubble-stock-sd-macos.sh" \
    "$repo_root/scripts/prepare-bubble-clone-boot-probe-macos.sh" \
    "$repo_root/scripts/install-bubble-system-boot-probe-over-ssh.sh" \
    "$repo_root/scripts/build-bubble-tools-image.sh" \
    "$repo_root/scripts/build-bubble-minimal-system.sh" \
    "$repo_root/scripts/build-bubble-seed-image.sh" \
    "$repo_root/scripts/capture-bubble-boot-substrate-over-ssh.sh" \
    "$repo_root/scripts/verify-bubble-seed-image.sh" \
    "$repo_root/scripts/write-bubble-seed-image-macos.sh" \
    "$repo_root/rootfs/bubble-minimal/init"

python3 -m py_compile \
    "$repo_root/scripts/mkimage-uboot-script.py" \
    "$repo_root/scripts/instrument-bubble-boot-script.py" \
    "$repo_root/scripts/generate-bubble-fb-marker.py"

python3 "$repo_root/scripts/mkimage-uboot-script.py" \
    --timestamp 1708596191 \
    "$repo_root/artifacts/vendor/bubble-stock-source/boot/boot.cmd" \
    "$test_dir/rebuilt.scr"
cmp "$repo_root/artifacts/vendor/bubble-stock-source/boot/boot.scr" "$test_dir/rebuilt.scr"

python3 "$repo_root/scripts/instrument-bubble-boot-script.py" \
    "$repo_root/artifacts/vendor/bubble-stock-source/boot/boot.cmd" \
    "$test_dir/instrumented"

python3 - "$test_dir/instrumented/boot.scr" <<'PY'
from pathlib import Path
import struct
import sys
import zlib

image = Path(sys.argv[1]).read_bytes()
header = struct.unpack(">7I4B32s", image[:64])
assert header[0] == 0x27051956
assert zlib.crc32(image[:4] + bytes(4) + image[8:64]) & 0xFFFFFFFF == header[1]
assert zlib.crc32(image[64 : 64 + header[3]]) & 0xFFFFFFFF == header[6]
assert header[9] == 6
PY

for stage in S10 S11 S12 E12 S13 E13 S14 S19 E20; do
    grep -q "$stage" "$test_dir/instrumented/boot.cmd"
done

python3 "$repo_root/scripts/generate-bubble-fb-marker.py" "$test_dir/marker.raw"
test "$(stat -f '%z' "$test_dir/marker.raw")" -eq 1228800

echo "Bubble boot probe tests passed"
