#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch
controller=$repo_root/package/frontend-bubble/plumos/bin/plumos-controller-ui-bubble
scanner=$repo_root/src/frontend/plumos_library_scan.c

grep -q "grep -qs ' /run/media/sd2 ' /proc/mounts" "$launcher"
grep -q 'PLUMOS_ROM_ROOT=$PLUMOS_SDCARD_ROOT' "$launcher"
grep -q 'case "$PLUMOS_ROM_ROOT" in /storage/\*)' "$launcher"
grep -q 'frontend_media=sdcard_root=' "$launcher"

grep -q "grep -qs ' /run/media/sd2 ' /proc/mounts" "$controller"
grep -q 'PLUMOS_ROM_ROOT=$PLUMOS_SDCARD_ROOT' "$controller"
grep -q 'rom_root_names\[\].*{"Roms", "roms", ""}' "$scanner"

echo 'bubble_frontend_media_root=result-ok external=/run/media/sd2 write_policy=read-only'
