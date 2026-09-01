#!/bin/sh
set -eu

usage() {
    echo "usage: PLUMOS_BUBBLE_CLONE_TARGET=/dev/diskN $0 /dev/diskSOURCE /dev/diskTARGET" >&2
    echo "TARGET is completely overwritten. Use whole external physical disks only." >&2
    exit 2
}

[ "$#" -eq 2 ] || usage
source_disk=$1
target_disk=$2
[ "$source_disk" != "$target_disk" ] || usage
[ "${PLUMOS_BUBBLE_CLONE_TARGET:-}" = "$target_disk" ] || {
    echo "refusing: PLUMOS_BUBBLE_CLONE_TARGET must exactly equal $target_disk" >&2
    exit 1
}

case "$source_disk" in /dev/disk[0-9]*) ;; *) usage ;; esac
case "$target_disk" in /dev/disk[0-9]*) ;; *) usage ;; esac
case "$source_disk$target_disk" in *s[0-9]*) usage ;; esac

source_id=${source_disk#/dev/}
target_id=${target_disk#/dev/}
source_raw=/dev/r$source_id
target_raw=/dev/r$target_id
expected_size=124383133696
expected_prefix_sha=648078e91860adf21bd4ec8f1fd8a64ce52de0ce24511393b156b920327b4ec2

disk_field() {
    diskutil info -plist "$1" | plutil -extract "$2" raw -o - -
}

validate_external_whole_disk() {
    disk=$1
    [ "$(disk_field "$disk" WholeDisk)" = "true" ] || {
        echo "refusing non-whole disk: $disk" >&2
        exit 1
    }
    [ "$(disk_field "$disk" Internal)" = "false" ] || {
        echo "refusing internal disk: $disk" >&2
        exit 1
    }
    [ "$(disk_field "$disk" RemovableMedia)" = "true" ] || {
        echo "refusing non-removable disk: $disk" >&2
        exit 1
    }
}

validate_external_whole_disk "$source_disk"
validate_external_whole_disk "$target_disk"
source_size=$(disk_field "$source_disk" TotalSize)
target_size=$(disk_field "$target_disk" TotalSize)
[ "$source_size" -eq "$expected_size" ] || {
    echo "refusing source with unexpected size: $source_size" >&2
    exit 1
}
[ "$target_size" -ge "$source_size" ] || {
    echo "target is smaller than source: $target_size < $source_size" >&2
    exit 1
}

diskutil unmountDisk "$source_disk"
diskutil unmountDisk "$target_disk"

prefix_sha=$(sudo dd if="$source_raw" bs=1m count=16 2>/dev/null | shasum -a 256 | awk '{print $1}')
[ "$prefix_sha" = "$expected_prefix_sha" ] || {
    echo "refusing source with unexpected 16 MiB prefix: $prefix_sha" >&2
    exit 1
}

echo "source: $source_disk $source_size bytes prefix=$prefix_sha"
echo "target: $target_disk $target_size bytes (WILL BE OVERWRITTEN)"
sudo dd if="$source_raw" of="$target_raw" bs=4m
sync

sudo cmp -n "$source_size" "$source_raw" "$target_raw"
echo "full source-size block readback matched"

diskutil mount "${target_disk}s1"
target_volume=$(diskutil info -plist "${target_disk}s1" | plutil -extract MountPoint raw -o - -)
mkdir -p "$target_volume/plumos-probe"
printf 'PLUMOS_BUBBLE_CLONE_PROBE_V1 %s\n' "$target_id" \
    > "$target_volume/plumos-probe/clone-authorized.txt"
sync

echo "authorized verified clone: $target_volume ($target_disk)"
echo "source remains unmounted; remove it before preparing or booting the clone"
