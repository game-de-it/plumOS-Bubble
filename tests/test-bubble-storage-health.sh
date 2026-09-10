#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-storage-health
repair=$repo_root/package/frontend-bubble/plumos/bin/plumos-sd2-repair
checker=$repo_root/package/frontend-bubble/plumos/bin/plumos-fsck-fat
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch
media_index=$repo_root/package/frontend-bubble/plumos/bin/plumos-library-index-media

sh -n "$helper"
sh -n "$repair"
sh -n "$checker"
sh -n "$media_index"
grep -Fq 'observe >>"$LOG"' "$launcher"
grep -Fq '[ "$MEDIA_ROOT" = /storage ]' "$helper"
grep -Fq 'MOUNTS_FILE=${PLUMOS_MOUNTS_FILE:-/proc/mounts}' "$helper"
test "$(grep -Fc 'plumos-storage-health" observe' "$launcher")" -eq 2
grep -Fq 'previous filesystem error remains until a read-only check proves clean' "$helper"
grep -Fq 'frontend_scan=skipped_dirty_media' "$launcher"
grep -Fq 'plumos-library-index-media' "$launcher"
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
grep -Fq '"$CHECKER" -a "$device"' "$repair"
grep -Fq 'PLUMOS_SD2_ACCESS="$access"' "$repair"
grep -Fq 'reason=os-device' "$repair"
grep -Fq 'reason=unmount-failed' "$repair"

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

# A dirty card must never reuse the active index from the SD1 fallback. With no
# card-specific cache the launcher is told to perform one read-only scan; after
# recording it, the same card can safely preserve or restore its own index.
mkdir -p "$tmp/root/state/frontend" "$tmp/user/config/system"
printf '{"systems":[{"id":"pyxel"}]}\n' >"$tmp/root/state/frontend/library-index.json"
printf 'device-mmcblk1p3\n' >"$tmp/root/state/frontend/active-owner-unused"
printf 'uuid=130C-1033\npartition=1\n' >"$tmp/user/config/system/sd2-identity.conf"
media_env="PLUMOS_ROOT=$tmp/root PLUMOS_BUSYBOX=$tmp/fake-busybox PLUMOS_SD2_IDENTITY_FILE=$tmp/user/config/system/sd2-identity.conf"
env $media_env sh "$media_index" prepare >"$tmp/media-prepare.log"
grep -q 'library_media=scan key=uuid-130C-1033 result=dirty reason=no-matching-index' "$tmp/media-prepare.log"
printf '{"systems":[{"id":"nes","rom_count":118}]}\n' >"$tmp/root/state/frontend/library-index.json"
env $media_env sh "$media_index" record >"$tmp/media-record.log"
grep -q '^uuid-130C-1033$' "$tmp/root/state/frontend/media-index/active-media"
env $media_env sh "$media_index" prepare >"$tmp/media-preserve.log"
grep -q 'library_media=preserved key=uuid-130C-1033 result=dirty source=active' "$tmp/media-preserve.log"

# Switching to SD1 records a different active index but retains the SD2 cache;
# reinsertion restores the UUID-matched index rather than preserving SD1 data.
cat >"$tmp/root/state/storage-health/status" <<'EOF'
result=observed
mount_path=/storage
device=/dev/mmcblk1p3
filesystem=ext4
EOF
printf '{"systems":[{"id":"pyxel"}]}\n' >"$tmp/root/state/frontend/library-index.json"
env $media_env sh "$media_index" record >"$tmp/media-sd1-record.log"
cat >"$tmp/root/state/storage-health/status" <<'EOF'
result=dirty
mount_path=/run/media/sd2
device=/dev/mmcblk3p1
filesystem=vfat
EOF
env $media_env sh "$media_index" prepare >"$tmp/media-restore.log"
grep -q 'library_media=preserved key=uuid-130C-1033 result=dirty source=cache' "$tmp/media-restore.log"
grep -q '"id":"nes"' "$tmp/root/state/frontend/library-index.json"

# Explicit repair is separate from passive observation. It unmounts the exact
# FAT SD2, runs automatic repair with a bound, and restores rw only on success.
repair_device=$tmp/sd2.img
: >"$repair_device"
cat >"$tmp/fake-mount-helper" <<'EOF'
#!/bin/sh
case ${1:-} in
    stop)
        [ "${PLUMOS_TEST_REPAIR_UNMOUNT_FAIL:-0}" != 1 ] || exit 1
        : >"$PLUMOS_TEST_REPAIR_MOUNTS"
        ;;
    start)
        printf '%s %s vfat %s 0 0\n' "$PLUMOS_TEST_REPAIR_DEVICE" \
            "$PLUMOS_SDCARD_ROOT" "$PLUMOS_SD2_ACCESS" \
            >"$PLUMOS_TEST_REPAIR_MOUNTS"
        ;;
    *) exit 2 ;;
esac
EOF
cat >"$tmp/fake-checker" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$PLUMOS_TEST_REPAIR_ARGS"
exit "${PLUMOS_TEST_REPAIR_RC:-0}"
EOF
cat >"$tmp/fake-timeout" <<'EOF'
#!/bin/sh
shift
exec "$@"
EOF
chmod +x "$tmp/fake-mount-helper" "$tmp/fake-checker" "$tmp/fake-timeout"
printf '%s /run/media/sd2 vfat rw 0 0\n' "$repair_device" >"$tmp/repair-mounts"
repair_env="PLUMOS_ROOT=$tmp/root PLUMOS_SDCARD_ROOT=/run/media/sd2 PLUMOS_MOUNTS_FILE=$tmp/repair-mounts PLUMOS_BUSYBOX=$tmp/fake-busybox PLUMOS_SD2_MOUNT_HELPER=$tmp/fake-mount-helper PLUMOS_FAT_CHECKER=$tmp/fake-checker PLUMOS_TIMEOUT=$tmp/fake-timeout PLUMOS_SD2_REPAIR_LOCK=$tmp/repair-lock PLUMOS_SD2_TEST_ALLOW_REGULAR=1 PLUMOS_TEST_REPAIR_MOUNTS=$tmp/repair-mounts PLUMOS_TEST_REPAIR_DEVICE=$repair_device PLUMOS_TEST_REPAIR_ARGS=$tmp/repair-args"
env $repair_env sh "$repair" >"$tmp/repair-ok.log"
grep -q '^result=clean$' "$tmp/root/state/storage-health/status"
grep -qx -- "-a $repair_device" "$tmp/repair-args"
grep -q ' /run/media/sd2 vfat rw ' "$tmp/repair-mounts"

# An uncorrected error is never remounted writable.
printf '%s /run/media/sd2 vfat rw 0 0\n' "$repair_device" >"$tmp/repair-mounts"
set +e
env $repair_env PLUMOS_TEST_REPAIR_RC=4 sh "$repair" >"$tmp/repair-fail.log" 2>&1
repair_rc=$?
set -e
test "$repair_rc" -ne 0
grep -q '^result=dirty$' "$tmp/root/state/storage-health/status"
grep -q ' /run/media/sd2 vfat ro ' "$tmp/repair-mounts"

# The OS disk and a busy SD2 are rejected before any checker invocation.
: >"$tmp/mmcblk1p3"
: >"$tmp/mmcblk1p4"
printf '%s /storage ext4 rw 0 0\n%s /run/media/sd2 vfat rw 0 0\n' \
    "$tmp/mmcblk1p3" "$tmp/mmcblk1p4" >"$tmp/repair-mounts"
set +e
env $repair_env PLUMOS_TEST_REPAIR_DEVICE="$tmp/mmcblk1p4" \
    sh "$repair" >"$tmp/repair-os-refused.log" 2>&1
repair_rc=$?
set -e
test "$repair_rc" -ne 0
grep -q 'reason=os-device' "$tmp/root/logs/storage-health.log"

printf '%s /run/media/sd2 vfat rw 0 0\n' "$repair_device" >"$tmp/repair-mounts"
set +e
env $repair_env PLUMOS_TEST_REPAIR_UNMOUNT_FAIL=1 \
    sh "$repair" >"$tmp/repair-busy.log" 2>&1
repair_rc=$?
set -e
test "$repair_rc" -ne 0
grep -q '^result=repair_refused$' "$tmp/root/state/storage-health/status"
grep -q ' /run/media/sd2 vfat rw ' "$tmp/repair-mounts"

printf 'bubble_storage_health=result-ok startup_observe=yes media_state=isolated library_index=media-owned automatic_repair=explicit-only mounted_rw_check=refused\n'
