#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-bubble-mount-sd2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

sd2=$tmp/sd2
user=$tmp/user
mkdir -p "$sd2/roms/FC" "$sd2/bios" "$user/Roms" "$user/BIOS" \
    "$tmp/root/logs" "$tmp/run"
printf 'rom\n' >"$sd2/roms/FC/test.nes"
printf '/dev/fake-sd2 %s vfat ro 0 0\n' "$sd2" >"$tmp/mounts"

cat >"$tmp/fake-busybox" <<'EOF'
#!/bin/sh
command_name=$1
shift
case "$command_name" in
    mount)
        [ "$1" = --bind ] || exit 2
        source_dir=$2
        target_dir=$3
        device=$(awk -v path="$PLUMOS_TEST_SD2" '$2 == path { print $1; exit }' \
            "$PLUMOS_MOUNTS_FILE")
        printf '%s %s none ro,bind 0 0\n' "$device" "$target_dir" \
            >>"$PLUMOS_MOUNTS_FILE"
        printf '%s -> %s\n' "$source_dir" "$target_dir" >>"$PLUMOS_TEST_CALLS"
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
    PLUMOS_SD2_DEVICE=/dev/fake-sd2 \
    PLUMOS_SD2_MOUNTPOINT="$sd2" \
    PLUMOS_MOUNTS_FILE="$tmp/mounts" \
    PLUMOS_BUSYBOX="$tmp/fake-busybox" \
    PLUMOS_TEST_SD2="$sd2" \
    PLUMOS_TEST_CALLS="$tmp/calls" \
        sh "$helper" "$1"
}

run_helper start >"$tmp/start.log"
grep -q 'sd2_content=result-started' "$tmp/start.log"
grep -q "/dev/fake-sd2 $user/Roms " "$tmp/mounts"
grep -q "/dev/fake-sd2 $user/BIOS " "$tmp/mounts"
test "$(grep -c "/dev/fake-sd2 $user/Roms " "$tmp/mounts")" -eq 1

run_helper start >"$tmp/restart.log"
grep -q 'sd2_bind=result-already-mounted content=roms' "$tmp/restart.log"
test "$(grep -c "/dev/fake-sd2 $user/Roms " "$tmp/mounts")" -eq 1

run_helper status >"$tmp/status.log"
grep -q "rom_target=$user/Roms" "$tmp/status.log"
grep -q '^rom_source=/dev/fake-sd2$' "$tmp/status.log"
grep -q '^bios_source=/dev/fake-sd2$' "$tmp/status.log"

run_helper stop >"$tmp/stop.log"
grep -q 'sd2_content=result-stopped fallback=sd1' "$tmp/stop.log"
! grep -q "/dev/fake-sd2 $user/Roms " "$tmp/mounts"
! grep -q "/dev/fake-sd2 $user/BIOS " "$tmp/mounts"
! grep -q "/dev/fake-sd2 $sd2 " "$tmp/mounts"

printf 'bubble_sd2_content_mount=result-ok stable_rom=/storage/Roms fallback=sd1\n'
