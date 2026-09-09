#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-storage-health
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch
media_index=$repo_root/package/frontend-bubble/plumos/bin/plumos-library-index-media

sh -n "$helper"
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

printf 'bubble_storage_health=result-ok startup_observe=yes media_state=isolated library_index=media-owned repair=never mounted_rw_check=refused\n'
