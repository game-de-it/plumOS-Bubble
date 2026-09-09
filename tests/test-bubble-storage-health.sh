#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-storage-health
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch

sh -n "$helper"
grep -Fq 'observe >>"$LOG"' "$launcher"
grep -Fq '[ "$MEDIA_ROOT" = /storage ]' "$helper"
grep -Fq 'MOUNTS_FILE=${PLUMOS_MOUNTS_FILE:-/proc/mounts}' "$helper"
test "$(grep -Fc 'plumos-storage-health" observe' "$launcher")" -eq 2
grep -Fq 'previous filesystem error remains until a read-only check proves clean' "$helper"
grep -Fq 'frontend_scan=skipped_dirty_media' "$launcher"
grep -Fq '[ -s "$PLUMOS_ROOT/state/frontend/library-index.json" ]' "$launcher"
grep -Fq "result=check_refused" "$helper"
grep -Fq "read-only check refused because media is mounted read-write" "$helper"
grep -Fq '"$checker" -n "$device"' "$helper"
test "$(grep -Fc '"$BB" sync' "$helper")" -eq 1
grep -Fq '[ "$ACTION" != check ] || "$BB" sync' "$helper"
grep -Fq 'frontend_network=background-owner-system' "$launcher"
grep -Fq 'frontend_network=background-reconcile-dispatched' "$launcher"
if grep -Eq 'fsck\.(fat|vfat).*-[ary]|dosfsck.*-[ary]' "$helper"; then
    echo 'bubble_storage_health=result-failed reason=repair-option-present' >&2
    exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
mkdir -p "$tmp/root/state/storage-health" "$tmp/root/logs"
cat >"$tmp/fake-busybox" <<'EOF'
#!/bin/sh
command_name=$1
shift
exec "$command_name" "$@"
EOF
chmod +x "$tmp/fake-busybox"
cat >"$tmp/root/state/storage-health/status" <<'EOF'
result=dirty
last_check=old
mount_path=/run/media/sd2
device=/dev/mmcblk3p1
filesystem=vfat
mount_options=rw
evidence=fixture dirty FAT
EOF
printf '/dev/mmcblk3p1 /run/media/sd2 vfat rw 0 0\n' >"$tmp/mounts"
PLUMOS_ROOT="$tmp/root" PLUMOS_SDCARD_ROOT=/run/media/sd2 \
PLUMOS_MOUNTS_FILE="$tmp/mounts" PLUMOS_BUSYBOX="$tmp/fake-busybox" \
    sh "$helper" observe >"$tmp/sd2-observe.log"
grep -q '^result=dirty$' "$tmp/root/state/storage-health/status"
grep -q '^result=dirty$' "$tmp/root/state/storage-health/media-mmcblk3p1.status"

# Removing SD2 while powered off must not transfer its sticky FAT state to the
# OS-side ext4 fallback or preserve an SD2-populated library index.
printf '/dev/mmcblk1p3 /storage ext4 rw 0 0\n' >"$tmp/mounts"
PLUMOS_ROOT="$tmp/root" PLUMOS_SDCARD_ROOT=/storage \
PLUMOS_MOUNTS_FILE="$tmp/mounts" PLUMOS_BUSYBOX="$tmp/fake-busybox" \
    sh "$helper" observe >"$tmp/storage-observe.log"
grep -q '^result=observed$' "$tmp/root/state/storage-health/status"
grep -q '^device=/dev/mmcblk1p3$' "$tmp/root/state/storage-health/status"

# Reinserting the same card on a later boot restores that card's own dirty
# evidence instead of inheriting the ext4 fallback state.
printf '/dev/mmcblk3p1 /run/media/sd2 vfat rw 0 0\n' >"$tmp/mounts"
PLUMOS_ROOT="$tmp/root" PLUMOS_SDCARD_ROOT=/run/media/sd2 \
PLUMOS_MOUNTS_FILE="$tmp/mounts" PLUMOS_BUSYBOX="$tmp/fake-busybox" \
    sh "$helper" observe >"$tmp/sd2-return.log"
grep -q '^result=dirty$' "$tmp/root/state/storage-health/status"

printf 'bubble_storage_health=result-ok startup_observe=yes media_state=isolated repair=never mounted_rw_check=refused\n'
