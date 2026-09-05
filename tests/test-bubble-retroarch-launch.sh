#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [ "${1:-}" != --inside ]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./tests/test-bubble-retroarch-launch.sh --inside
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
rom_root=$tmp/roms
runtime=$tmp/run
mkdir -p "$root/bin" "$root/cores" \
    "$root/factory-defaults/retroarch" "$rom_root/nes" "$rom_root/n64" \
    "$runtime"
cp package/frontend-bubble/plumos/bin/plumos-retroarch-launch \
    "$root/bin/plumos-retroarch-launch"
cp package/frontend-bubble/plumos/bin/plumos-retroarch-config-merge \
    "$root/bin/plumos-retroarch-config-merge"
cp configs/retroarch/bubble-software-drm.cfg \
    "$root/factory-defaults/retroarch/retroarch-bubble.cfg"
: >"$root/cores/quicknes_libretro.so"
: >"$root/cores/parallel_n64_libretro.so"
: >"$rom_root/nes/test.nes"
: >"$rom_root/n64/test.z64"

cat >"$root/bin/retroarch" <<'EOF'
#!/bin/sh
set -eu
: "${TEST_TRACE:?}"
printf '%s\n' "$@" >"$TEST_TRACE.args"
append=
while [ "$#" -gt 0 ]; do
    if [ "$1" = --appendconfig ]; then append=$2; shift 2; else shift; fi
done
if [ -n "$append" ]; then cp "$append" "$TEST_TRACE.append"; fi
printf '%s\n' "$$" >"$TEST_TRACE.pid"
if [ "${TEST_HOLD:-0}" = 1 ]; then
    trap 'exit 0' TERM
    while :; do sleep 1; done
fi
EOF
cat >"$root/bin/plumos-audio-output" <<'EOF'
#!/bin/sh
mkdir -p "${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio"
: >"${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/asound.conf"
EOF
cat >"$root/bin/plumos-volume-control" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$root/bin/plumos-cpu-control" <<'EOF'
#!/bin/sh
case "$1" in
    snapshot) printf '%s\n' 'policy0=ondemand' >"$2" ;;
    apply|restore) ;;
    *) exit 2 ;;
esac
EOF
chmod 0755 "$root/bin/retroarch" "$root/bin/plumos-retroarch-launch" \
    "$root/bin/plumos-retroarch-config-merge" "$root/bin/plumos-audio-output" \
    "$root/bin/plumos-volume-control" "$root/bin/plumos-cpu-control"

run_launcher() {
    trace=$1
    shift
    TEST_TRACE=$trace PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
    PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
        "$root/bin/plumos-retroarch-launch" "$@"
}

run_launcher "$tmp/software" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes"
grep -qx -- --appendconfig "$tmp/software.args"
grep -qx 'video_driver = "drm"' "$tmp/software.append"
grep -qx 'video_context_driver = ""' "$tmp/software.append"
grep -qx 'video_threaded = "true"' "$tmp/software.append"
grep -qx 'system_directory = "/storage/BIOS"' "$tmp/software.append"
grep -qx 'log_to_file = "false"' "$tmp/software.append"
grep -qx 'savefiles_in_content_dir = "false"' "$tmp/software.append"
grep -qx 'savestates_in_content_dir = "false"' "$tmp/software.append"
grep -qx "savefile_directory = \"$root/saves\"" "$tmp/software.append"
grep -qx "savestate_directory = \"$root/states\"" "$tmp/software.append"
grep -qx 'audio_device = "plumos_output"' "$tmp/software.append"
! grep -q '^config_save_on_exit = ' "$tmp/software.append"
! find "$runtime/retroarch" -type f -name 'launch.*.cfg' -print -quit | grep -q .

# Bubble exposes SD2 through /storage/Roms -> /storage/user/Roms while the
# scanner records the resolved /storage/user/Roms path.  Both names identify
# the same managed ROM tree and must pass the traversal guard.
ln -s "$rom_root" "$tmp/rom-link"
TEST_TRACE=$tmp/symlink PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$tmp/rom-link \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes"
grep -qx "$rom_root/nes/test.nes" "$tmp/symlink.args"

set +e
TEST_TRACE=$tmp/escape PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$tmp/rom-link \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$root/cores/quicknes_libretro.so" \
    >"$tmp/escape.log" 2>&1
escape_rc=$?
set -e
test "$escape_rc" -eq 2
grep -q 'ROM path escaped configured ROM root' "$tmp/escape.log"

sed -i 's/^menu_driver = "rgui"$/menu_driver = "xmb"/' \
    "$root/config/retroarch/retroarch-bubble.cfg"
run_launcher "$tmp/xmb" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes"
grep -qx 'video_driver = "gl"' "$tmp/xmb.append"
grep -qx 'video_context_driver = "kms"' "$tmp/xmb.append"
sed -i 's/^menu_driver = "xmb"$/menu_driver = "rgui"/' \
    "$root/config/retroarch/retroarch-bubble.cfg"

run_launcher "$tmp/hardware" --system n64 \
    --core "$root/cores/parallel_n64_libretro.so" \
    --rom "$rom_root/n64/test.z64"
grep -qx 'video_driver = "gl"' "$tmp/hardware.append"
grep -qx 'video_context_driver = "kms"' "$tmp/hardware.append"
grep -qx 'video_threaded = "true"' "$tmp/hardware.append"
grep -qx 'system_directory = "/storage/BIOS"' "$tmp/hardware.append"
grep -qx 'log_to_file = "false"' "$tmp/hardware.append"
grep -qx 'savefiles_in_content_dir = "false"' "$tmp/hardware.append"
grep -qx 'savestates_in_content_dir = "false"' "$tmp/hardware.append"
grep -qx 'audio_device = "plumos_output"' "$tmp/hardware.append"
! grep -q '^config_save_on_exit = ' "$tmp/hardware.append"
! find "$runtime/retroarch" -type f -name 'launch.*.cfg' -print -quit | grep -q .

TEST_TRACE=$tmp/signal TEST_HOLD=1 PLUMOS_ROOT=$root \
PLUMOS_ROM_ROOT=$rom_root PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes" &
launcher_pid=$!
i=0
while [ ! -s "$tmp/signal.pid" ] && [ "$i" -lt 50 ]; do
    /bin/busybox usleep 100000
    i=$((i + 1))
done
test -s "$tmp/signal.pid"
child_pid=$(cat "$tmp/signal.pid")
kill -TERM "$launcher_pid"
set +e
wait "$launcher_pid"
launcher_rc=$?
set -e
test "$launcher_rc" -eq 143
! kill -0 "$child_pid" 2>/dev/null

echo 'bubble_retroarch_launcher_test=result-ok'
