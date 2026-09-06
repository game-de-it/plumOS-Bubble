#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PACKAGE="$ROOT_DIR/package/portmaster-bubble/plumos"
RUNTIME="$PACKAGE/bin/plumos-portmaster-runtime"
GUI_LAUNCH="$PACKAGE/bin/plumos-portmaster-launch"
PORT_LAUNCH="$PACKAGE/bin/plumos-portmaster-port-launch"
MOUNT_CLEANUP="$PACKAGE/bin/plumos-portmaster-mount-cleanup"
BUILDER="$ROOT_DIR/scripts/build-portmaster-bubble.sh"
UPDATER="$PACKAGE/apps/portmaster/adapter/plumos_portmaster_update.py"

for file in "$RUNTIME" "$GUI_LAUNCH" "$PORT_LAUNCH" "$MOUNT_CLEANUP"; do
    /bin/sh -n "$file"
done

grep -q 'link_one libgthread-2.0.so.0' "$RUNTIME"
grep -q 'link_one libglib-2.0.so.0' "$RUNTIME"
grep -q 'link_one libpcre2-8.so.0' "$RUNTIME"
grep -q 'link_one librt.so.1' "$RUNTIME"
grep -q 'ctypes.CDLL("libSDL2_mixer-2.0.so.0")' "$GUI_LAUNCH"
grep -q 'RESTART_FILE="${PM_DIR}/.pugwash-reboot"' "$GUI_LAUNCH"
grep -q 'restart-marker=stale action=consume' "$GUI_LAUNCH"
grep -q 'restart-marker=requested count=' "$GUI_LAUNCH"
grep -q 'plumos-portmaster-mount-cleanup' "$GUI_LAUNCH" "$PORT_LAUNCH"
grep -q 'libgthread-2.0.so.0:libgthread-2.0.so.0.' "$BUILDER"

builder_version="$(sed -n 's/^ADAPTER_VERSION="\([0-9][0-9]*\)"$/\1/p' "$BUILDER")"
updater_version="$(sed -n 's/^ADAPTER_VERSION = \([0-9][0-9]*\)$/\1/p' "$UPDATER")"
[ "$builder_version" = "$updater_version" ]

work="$(mktemp -d /tmp/plumos-portmaster-bubble-test.XXXXXX)"
trap 'rm -rf "$work"' EXIT
plumos_root="$work/plumos"
run_root="$work/run"
pm_dir="$plumos_root/state/portmaster/data/upstream/PortMaster"
mountinfo="$work/mountinfo"
track="$run_root/port.mounts"
mkdir -p "$run_root" "$pm_dir/config"

write_mountinfo() {
    printf '10 1 0:1 / /usr/lib/compat rw - tmpfs tmpfs rw\n' > "$mountinfo"
    printf '11 1 0:2 / %s/config rw - tmpfs tmpfs rw\n' "$pm_dir" >> "$mountinfo"
}

printf '%s\n' '#!/bin/sh' \
    'lazy=0' \
    'if [ "${1:-}" = -l ]; then lazy=1; shift; fi' \
    'target=$1' \
    'printf "lazy=%s target=%s\n" "$lazy" "$target" >> "$FAKE_UMOUNT_LOG"' \
    'if [ "$target" = "$FAKE_BUSY_TARGET" ] && [ "$lazy" -eq 0 ] && [ ! -f "$FAKE_BUSY_ONCE" ]; then : > "$FAKE_BUSY_ONCE"; exit 1; fi' \
    'awk -v target="$target" '\''$5 != target'\'' "$FAKE_MOUNTINFO" > "$FAKE_MOUNTINFO.tmp"' \
    'mv "$FAKE_MOUNTINFO.tmp" "$FAKE_MOUNTINFO"' > "$work/umount"
chmod 0755 "$work/umount"

if PLUMOS_ROOT="$plumos_root" PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
   PLUMOS_PORTMASTER_MOUNTINFO="$mountinfo" \
   /bin/sh "$MOUNT_CLEANUP" "$work/unmanaged.track" 2>/dev/null; then
    printf 'mount cleanup accepted an unmanaged tracking file\n' >&2
    exit 1
fi

write_mountinfo
printf '%s\n%s\n%s\n' /usr/lib/compat "$pm_dir/config" / > "$track"
FAKE_UMOUNT_LOG="$work/umount.log" \
FAKE_BUSY_TARGET="$pm_dir/config" \
FAKE_BUSY_ONCE="$work/busy-once" \
FAKE_MOUNTINFO="$mountinfo" \
PLUMOS_ROOT="$plumos_root" \
PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
PLUMOS_PORTMASTER_MOUNTINFO="$mountinfo" \
PLUMOS_PORTMASTER_UMOUNT_BIN="$work/umount" \
PLUMOS_PORTMASTER_SLEEP_BIN=true \
    /bin/sh "$MOUNT_CLEANUP" "$track"

[ ! -s "$mountinfo" ]
[ ! -e "$track" ]
grep -q "target=/usr/lib/compat" "$work/umount.log"
grep -q "target=$pm_dir/config" "$work/umount.log"
! grep -q 'target=/$' "$work/umount.log"

printf 'portmaster_bubble_runtime=result-ok adapter=%s gui_preflight=1 restart=1 mount_recovery=1\n' \
    "$builder_version"
