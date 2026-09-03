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
grep -Fq 'mount --bind "$source_dir" "$target_dir"' "$mount_helper"
grep -Fq 'fallback=sd1' "$mount_helper"
grep -Fq 'stop) stop_sd2' "$mount_helper"
grep -Fq 'plumos-bubble-mount-sd2' "$launcher"
grep -Fq 'plumos-bubble-mount-sd2' "$controller"

grep -Fq 'PLUMOS_SDCARD_ROOT=${PLUMOS_SDCARD_ROOT:-/storage}' "$launcher"
grep -Fq 'PLUMOS_ROM_ROOT=${PLUMOS_ROM_ROOT:-/storage/Roms}' "$launcher"
grep -Fq 'PLUMOS_BIOS_ROOT=${PLUMOS_BIOS_ROOT:-/storage/BIOS}' "$launcher"
! grep -q 'PLUMOS_SDCARD_ROOT=/run/media/sd2' "$launcher"
grep -q 'case "$PLUMOS_ROM_ROOT" in /storage/\*)' "$launcher"
grep -q 'mkdir -p "$PLUMOS_ROM_ROOT/FC".*|| true' "$launcher"
grep -q 'network_services_reconcile=result-complete' "$launcher"
grep -q 'frontend_media=sdcard_root=' "$launcher"
grep -q 'timeout -s TERM -k 5 "$SCAN_TIMEOUT"' "$launcher"
grep -q 'frontend_scan=bounded_failure.*index=preserved' "$launcher"

grep -Fq 'PLUMOS_SDCARD_ROOT=${PLUMOS_SDCARD_ROOT:-/storage}' "$controller"
grep -Fq 'PLUMOS_ROM_ROOT=${PLUMOS_ROM_ROOT:-/storage/Roms}' "$controller"
grep -Fq 'PLUMOS_BIOS_ROOT=${PLUMOS_BIOS_ROOT:-/storage/BIOS}' "$controller"
! grep -q 'PLUMOS_SDCARD_ROOT=/run/media/sd2' "$controller"
grep -q 'rom_root_names\[\].*{"Roms", "roms", ""}' "$scanner"

echo 'bubble_frontend_media_root=result-ok stable=/storage/Roms external=/run/media/sd2 write_policy=read-only'
