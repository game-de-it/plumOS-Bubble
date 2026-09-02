#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch
controller=$repo_root/package/frontend-bubble/plumos/bin/plumos-controller-ui-bubble
scanner=$repo_root/src/frontend/plumos_library_scan.c
mount_helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-bubble-mount-sd2

sh -n "$mount_helper"
grep -Fq 'mount -t vfat -o ro,utf8,shortname=mixed,errors=remount-ro' "$mount_helper"
grep -Fq 'reason=os-storage-device' "$mount_helper"
grep -Fq 'plumos-bubble-mount-sd2' "$launcher"
grep -Fq 'plumos-bubble-mount-sd2' "$controller"

grep -q "grep -qs ' /run/media/sd2 ' /proc/mounts" "$launcher"
grep -Fq '[ "$PLUMOS_SDCARD_ROOT" = /storage ]' "$launcher"
grep -q 'PLUMOS_ROM_ROOT=$PLUMOS_SDCARD_ROOT' "$launcher"
grep -q 'case "$PLUMOS_ROM_ROOT" in /storage/\*)' "$launcher"
grep -q 'frontend_media=sdcard_root=' "$launcher"
grep -q 'timeout -s TERM -k 5 "$SCAN_TIMEOUT"' "$launcher"
grep -q 'frontend_scan=bounded_failure.*index=preserved' "$launcher"

grep -q "grep -qs ' /run/media/sd2 ' /proc/mounts" "$controller"
grep -Fq '[ "$PLUMOS_SDCARD_ROOT" = /storage ]' "$controller"
grep -q 'PLUMOS_ROM_ROOT=$PLUMOS_SDCARD_ROOT' "$controller"
grep -q 'rom_root_names\[\].*{"Roms", "roms", ""}' "$scanner"

echo 'bubble_frontend_media_root=result-ok external=/run/media/sd2 write_policy=read-only'
