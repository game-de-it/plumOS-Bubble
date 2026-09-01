#!/bin/sh
set -eu

usage() {
    echo "usage: $0 /Volumes/CLONE_BOOT" >&2
    echo "The volume must be partition 1 of a verified clone, not the original OS SD." >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
volume=${1%/}
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
expected_cmd=88bd25f6883cbb8a2baba0d2322289f1664b73dceef08197e137ad93bd2b04b8
expected_scr=bd1395eb7f8e3d8a8858d21f8df83ce80863c0457b8b408e33065f958e2c8e20

[ -d "$volume" ] || usage
device_id=$(diskutil info -plist "$volume" | plutil -extract DeviceIdentifier raw -o - -)
parent_id=$(diskutil info -plist "$volume" | plutil -extract ParentWholeDisk raw -o - -)
[ -n "$device_id" ] && [ -n "$parent_id" ] || usage

authorization_file="$volume/plumos-probe/clone-authorized.txt"
if [ ! -f "$authorization_file" ]; then
    echo "refusing $volume: clone authorization marker is missing" >&2
    echo "Create this marker only as the final step of a verified device-to-device clone." >&2
    exit 1
fi
grep -qx "PLUMOS_BUBBLE_CLONE_PROBE_V1 $parent_id" "$authorization_file" || {
    echo "refusing $volume: marker does not authorize /dev/$parent_id" >&2
    exit 1
}

actual_cmd=$(shasum -a 256 "$volume/boot.cmd" | awk '{print $1}')
actual_scr=$(shasum -a 256 "$volume/boot.scr" | awk '{print $1}')
[ "$actual_cmd" = "$expected_cmd" ] || {
    echo "refusing unknown boot.cmd: $actual_cmd" >&2
    exit 1
}
[ "$actual_scr" = "$expected_scr" ] || {
    echo "refusing unknown boot.scr: $actual_scr" >&2
    exit 1
}

build_dir="$repo_root/work/bubble-boot-probe"
python3 "$repo_root/scripts/instrument-bubble-boot-script.py" \
    "$repo_root/artifacts/vendor/bubble-stock-source/boot/boot.cmd" "$build_dir"

mkdir -p "$volume/plumos-probe/original"
cp -p "$volume/boot.cmd" "$volume/plumos-probe/original/boot.cmd"
cp -p "$volume/boot.scr" "$volume/plumos-probe/original/boot.scr"
printf '----\n' > "$volume/plumos-probe/uboot-stage.txt"
cp "$build_dir/boot.cmd" "$volume/boot.cmd.incoming"
cp "$build_dir/boot.scr" "$volume/boot.scr.incoming"
sync
mv -f "$volume/boot.cmd.incoming" "$volume/boot.cmd"
mv -f "$volume/boot.scr.incoming" "$volume/boot.scr"
sync

test "$(shasum -a 256 "$volume/boot.cmd" | awk '{print $1}')" = \
    "$(shasum -a 256 "$build_dir/boot.cmd" | awk '{print $1}')"
test "$(shasum -a 256 "$volume/boot.scr" | awk '{print $1}')" = \
    "$(shasum -a 256 "$build_dir/boot.scr" | awk '{print $1}')"

echo "instrumented clone boot volume: $volume (/dev/$device_id, parent /dev/$parent_id)"
echo "original boot.cmd/boot.scr preserved under $volume/plumos-probe/original"
