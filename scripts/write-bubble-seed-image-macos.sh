#!/bin/sh
set -eu

usage() {
    echo "usage: PLUMOS_BUBBLE_WRITE_TARGET=/dev/diskN $0 IMAGE /dev/diskN" >&2
    echo "The whole target disk is overwritten." >&2
    exit 2
}

[ "$#" -eq 2 ] || usage
image=$1
target=$2
[ -f "$image" ] || usage
[ "${PLUMOS_BUBBLE_WRITE_TARGET:-}" = "$target" ] || {
    echo "refusing: PLUMOS_BUBBLE_WRITE_TARGET must exactly equal $target" >&2
    exit 1
}
case "$target" in /dev/disk[0-9]*) ;; *) usage;; esac
case "$target" in *s[0-9]*) usage;; esac

field() {
    diskutil info -plist "$target" | plutil -extract "$1" raw -o - -
}
[ "$(field WholeDisk)" = true ] || { echo 'target is not a whole disk' >&2; exit 1; }
[ "$target" != /dev/disk0 ] || { echo 'refusing system disk0' >&2; exit 1; }
[ "$(field RemovableMedia)" = true ] || { echo 'refusing non-removable media' >&2; exit 1; }
[ "$(field Ejectable)" = true ] || { echo 'refusing non-ejectable media' >&2; exit 1; }
[ "$(field WritableMedia)" = true ] || { echo 'refusing read-only media' >&2; exit 1; }
[ "$(field VirtualOrPhysical)" = Physical ] || { echo 'refusing non-physical target' >&2; exit 1; }
if [ "$(field Internal)" = true ]; then
    [ "$(field BusProtocol)" = 'Secure Digital' ] || {
        echo 'refusing internal non-SD target' >&2
        exit 1
    }
fi
image_size=$(stat -f '%z' "$image")
target_size=$(field TotalSize)
[ "$target_size" -ge "$image_size" ] || { echo 'target is smaller than image' >&2; exit 1; }

if [ "${PLUMOS_BUBBLE_VALIDATE_ONLY:-0}" = 1 ]; then
    echo "target validation passed: $target ($target_size bytes)"
    exit 0
fi

target_id=${target#/dev/}
raw_target=/dev/r$target_id
diskutil unmountDisk "$target"
echo "writing $image ($image_size bytes) to $target ($target_size bytes)"
sudo dd if="$image" of="$raw_target" bs=4m
sync
sudo cmp -n "$image_size" "$image" "$raw_target"
echo 'full image-size block readback matched'
diskutil eject "$target"
