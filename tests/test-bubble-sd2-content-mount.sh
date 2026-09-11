#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-bubble-mount-sd2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

sd2=$tmp/sd2
fake_device=$tmp/mmcblk3p1
user=$tmp/user
mkdir -p "$sd2/roms/FC" "$sd2/bios" "$user/Roms" "$user/BIOS" \
    "$tmp/root/logs" "$tmp/run"
printf 'rom\n' >"$sd2/roms/FC/test.nes"
dd if=/dev/zero of="$fake_device" bs=512 count=1 2>/dev/null
printf 'FAT32' | dd of="$fake_device" bs=1 seek=82 conv=notrunc 2>/dev/null
printf '\063\020\014\023' | dd of="$fake_device" bs=1 seek=67 conv=notrunc 2>/dev/null
printf '%s %s vfat rw 0 0\n' "$fake_device" "$sd2" >"$tmp/mounts"

cat >"$tmp/fake-busybox" <<'EOF'
#!/bin/sh
command_name=$1
shift
case "$command_name" in
    mount)
        if [ "$1" = --bind ]; then
            source_dir=$2
            target_dir=$3
            device=$(awk -v path="$PLUMOS_TEST_SD2" '$2 == path { print $1; exit }' \
                "$PLUMOS_MOUNTS_FILE")
            printf '%s %s none rw,bind 0 0\n' "$device" "$target_dir" \
                >>"$PLUMOS_MOUNTS_FILE"
            printf '%s -> %s\n' "$source_dir" "$target_dir" >>"$PLUMOS_TEST_CALLS"
        elif [ "$1" = -o ]; then
            options=$2
            target_dir=$3
            case ",$options," in *,rw,*) access=rw ;; *) access=ro ;; esac
            awk -v path="$target_dir" -v access="$access" \
                '{ if ($2 == path) $4 = access ",bind"; print }' \
                "$PLUMOS_MOUNTS_FILE" >"$PLUMOS_MOUNTS_FILE.next"
            mv "$PLUMOS_MOUNTS_FILE.next" "$PLUMOS_MOUNTS_FILE"
            printf 'remount %s %s\n' "$target_dir" "$access" >>"$PLUMOS_TEST_CALLS"
        elif [ "$1" = -t ]; then
            device=$5
            target_dir=$6
            options=$4
            case ",$options," in *,rw,*) access=rw ;; *) access=ro ;; esac
            printf '%s %s vfat %s 0 0\n' "$device" "$target_dir" "$access" \
                >>"$PLUMOS_MOUNTS_FILE"
            printf 'mount %s %s\n' "$device" "$target_dir" >>"$PLUMOS_TEST_CALLS"
        else
            exit 2
        fi
        ;;
    findfs)
        if [ "$1" = UUID=130C-1033 ]; then
            printf '%s\n' "$PLUMOS_TEST_DEVICE"
            exit 0
        fi
        exit 1
        ;;
    umount)
        target=$1
        awk -v path="$target" '$2 != path' "$PLUMOS_MOUNTS_FILE" \
            >"$PLUMOS_MOUNTS_FILE.next"
        mv "$PLUMOS_MOUNTS_FILE.next" "$PLUMOS_MOUNTS_FILE"
        printf 'unmount %s\n' "$target" >>"$PLUMOS_TEST_CALLS"
        ;;
    sync) ;;
    *) exec "$command_name" "$@" ;;
esac
EOF
chmod 0755 "$tmp/fake-busybox"

run_helper() {
    PLUMOS_ROOT="$tmp/root" \
    PLUMOS_RUNTIME_ROOT="$tmp/run" \
    PLUMOS_USERDATA_ROOT="$user" \
    PLUMOS_SD2_DEVICE="$fake_device" \
    PLUMOS_SD2_MOUNTPOINT="$sd2" \
    PLUMOS_MOUNTS_FILE="$tmp/mounts" \
    PLUMOS_BUSYBOX="$tmp/fake-busybox" \
    PLUMOS_TEST_SD2="$sd2" \
    PLUMOS_TEST_DEVICE="$fake_device" \
    PLUMOS_SD2_TEST_ALLOW_REGULAR=1 \
    PLUMOS_TEST_CALLS="$tmp/calls" \
        sh "$helper" "$1"
}

run_helper start >"$tmp/start.log"
grep -q 'sd2_content=result-started' "$tmp/start.log"
grep -q 'access=rw' "$tmp/start.log"
grep -Fq "$fake_device $user/Roms " "$tmp/mounts"
grep -Fq "$fake_device $user/BIOS " "$tmp/mounts"
test "$(grep -Fc "$fake_device $user/Roms " "$tmp/mounts")" -eq 1
grep -q '^uuid=130C-1033$' "$user/config/system/sd2-identity.conf"
grep -q '^partition=1$' "$user/config/system/sd2-identity.conf"

# A pre-existing read-only bind must follow a successful SD2 rw remount.
awk -v path="$user/Roms" \
    '{ if ($2 == path) $4 = "ro,bind"; print }' "$tmp/mounts" >"$tmp/mounts.next"
mv "$tmp/mounts.next" "$tmp/mounts"
run_helper start >"$tmp/restart.log"
grep -q 'sd2_bind=result-remounted content=roms.*access=rw' "$tmp/restart.log"
test "$(grep -Fc "$fake_device $user/Roms " "$tmp/mounts")" -eq 1

run_helper status >"$tmp/status.log"
grep -q "rom_target=$user/Roms" "$tmp/status.log"
grep -Fq "rom_source=$fake_device" "$tmp/status.log"
grep -Fq "bios_source=$fake_device" "$tmp/status.log"
grep -Fq "resolved_device=$fake_device" "$tmp/status.log"
grep -q '^resolved_by=explicit-device$' "$tmp/status.log"
grep -q '^sd2_access=rw$' "$tmp/status.log"

run_helper stop >"$tmp/stop.log"
grep -q 'sd2_content=result-stopped fallback=sd1' "$tmp/stop.log"
grep -q 'sd2_mount=result-remounted-before-unmount.*access=ro' "$tmp/stop.log"
remount_line=$(grep -n "remount $sd2 ro" "$tmp/calls" | tail -n 1 | cut -d: -f1)
unmount_line=$(grep -n "unmount $sd2" "$tmp/calls" | tail -n 1 | cut -d: -f1)
test "$remount_line" -lt "$unmount_line"
! grep -Fq "$fake_device $user/Roms " "$tmp/mounts"
! grep -Fq "$fake_device $user/BIOS " "$tmp/mounts"
! grep -Fq "$fake_device $sd2 " "$tmp/mounts"

# A later boot resolves the same card from its saved filesystem UUID even when
# no kernel device name override is supplied.
PLUMOS_ROOT="$tmp/root" \
PLUMOS_RUNTIME_ROOT="$tmp/run" \
PLUMOS_USERDATA_ROOT="$user" \
PLUMOS_SD2_MOUNTPOINT="$sd2" \
PLUMOS_MOUNTS_FILE="$tmp/mounts" \
PLUMOS_BUSYBOX="$tmp/fake-busybox" \
PLUMOS_TEST_SD2="$sd2" \
PLUMOS_TEST_DEVICE="$fake_device" \
PLUMOS_SD2_FALLBACK_DEVICE="$tmp/missing-fallback" \
PLUMOS_SD2_TEST_ALLOW_REGULAR=1 \
PLUMOS_TEST_CALLS="$tmp/calls" \
    sh "$helper" start >"$tmp/uuid-start.log"
grep -q 'selected_by=filesystem-uuid' "$tmp/uuid-start.log"
grep -Fq "$fake_device $sd2 " "$tmp/mounts"
run_helper stop >"$tmp/uuid-stop.log"

# A candidate partition on the same disk as /storage is always rejected.
os_partition=$tmp/mmcblk1p3
os_other_partition=$tmp/mmcblk1p1
: >"$os_partition"
: >"$os_other_partition"
printf '%s /storage ext4 rw 0 0\n' "$os_partition" >"$tmp/mounts"
PLUMOS_ROOT="$tmp/root" \
    PLUMOS_RUNTIME_ROOT="$tmp/run" \
    PLUMOS_USERDATA_ROOT="$user" \
    PLUMOS_SD2_DEVICE="$os_other_partition" \
    PLUMOS_SD2_MOUNTPOINT="$sd2" \
    PLUMOS_MOUNTS_FILE="$tmp/mounts" \
    PLUMOS_BUSYBOX="$tmp/fake-busybox" \
    PLUMOS_SD2_TEST_ALLOW_REGULAR=1 \
    PLUMOS_TEST_CALLS="$tmp/calls" \
        sh "$helper" start >"$tmp/os-refused.log" 2>&1
grep -q 'reason=invalid-or-os-device' "$tmp/os-refused.log"
grep -q 'sd2_mount=result-unavailable fallback=sd1' "$tmp/os-refused.log"
! grep -Fq "$os_other_partition $sd2 " "$tmp/mounts"

printf 'bubble_sd2_content_mount=result-ok stable_rom=/storage/Roms identity=uuid boot_only=yes fallback=sd1\n'
