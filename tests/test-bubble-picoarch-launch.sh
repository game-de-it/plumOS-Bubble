#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [ "${1:-}" != --inside ]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./tests/test-bubble-picoarch-launch.sh --inside
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
rom_root=$tmp/roms
runtime=$tmp/run
mkdir -p "$root/bin" "$root/picoarch/bin" "$root/picoarch/lib" \
    "$root/emulator/lib" "$root/cores" "$root/share/alsa" "$root/share/picoarch" \
    "$rom_root/nes" "$rom_root/gamegear" "$runtime"
cp package/picoarch-bubble/plumos/bin/plumos-picoarch-launch \
    "$root/bin/plumos-picoarch-launch"
cp package/picoarch-bubble/plumos/share/picoarch/rgb565-byte-order.tsv \
    "$root/share/picoarch/rgb565-byte-order.tsv"
: >"$root/cores/quicknes_libretro.so"
: >"$root/cores/gearsystem_libretro.so"
: >"$root/cores/picodrive_libretro.so"
: >"$root/share/alsa/alsa.conf"
: >"$rom_root/nes/test.nes"
: >"$rom_root/gamegear/test.gg"
cat >"$root/bin/plumos-cpu-control" <<'EOF'
#!/bin/sh
case $1 in
    snapshot) : >"$2" ;;
    apply) : ;;
    restore) rm -f "$2" ;;
    *) exit 2 ;;
esac
EOF

cat >"$root/picoarch/bin/picoarch" <<'EOF'
#!/bin/sh
set -eu
: "${TEST_TRACE:?}"
printf '%s\n' "$$" >"$TEST_TRACE.pid"
printf '%s\n' "${PLUMOS_PICOARCH_RGB565_BYTESWAP:-unset}" >"$TEST_TRACE.rgb565"
if [ "${TEST_HOLD:-0}" = 1 ]; then
    trap '' TERM
    while :; do sleep 1; done
fi
exit 0
EOF
chmod 0755 "$root/bin/plumos-picoarch-launch" \
    "$root/bin/plumos-cpu-control" "$root/picoarch/bin/picoarch"

TEST_TRACE=$tmp/normal PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=nes \
    "$root/bin/plumos-picoarch-launch" quicknes "$rom_root/nes/test.nes"
grep -Fqx 'picoarch=stage-P19 system=nes core=quicknes rc=0' \
    "$root/logs/session.log"
test "$(cat "$tmp/normal.rgb565")" = 0

TEST_TRACE=$tmp/forced-swap PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=nes \
PLUMOS_PICOARCH_RGB565_BYTESWAP=1 \
    "$root/bin/plumos-picoarch-launch" quicknes "$rom_root/nes/test.nes"
test "$(cat "$tmp/forced-swap.rgb565")" = 1

set +e
TEST_TRACE=$tmp/invalid-swap PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=nes \
PLUMOS_PICOARCH_RGB565_BYTESWAP=invalid \
    "$root/bin/plumos-picoarch-launch" quicknes "$rom_root/nes/test.nes"
invalid_swap_rc=$?
set -e
test "$invalid_swap_rc" -eq 2
test ! -e "$tmp/invalid-swap.pid"

# Gearsystem and PicoDrive both need byte-order correction before PicoArch's
# 16-bit scaler. Device screenshots otherwise turn the blue SEGA screen green.
TEST_TRACE=$tmp/gearsystem PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=gamegear \
    "$root/bin/plumos-picoarch-launch" gearsystem "$rom_root/gamegear/test.gg"
test "$(cat "$tmp/gearsystem.rgb565")" = 1
grep -Fqx 'picoarch=video-format core=gearsystem pixel_format=rgb565 byte_order=byteswap rgb565_byteswap=1 evidence=device-ra-genesis-plus-gx-anchor-90f' \
    "$root/logs/picoarch-gamegear-gearsystem.log"

TEST_TRACE=$tmp/picodrive PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=gamegear \
    "$root/bin/plumos-picoarch-launch" picodrive "$rom_root/gamegear/test.gg"
test "$(cat "$tmp/picodrive.rgb565")" = 1

# The normal FE exposes content through /storage/user/Roms while the legacy
# compatibility root is /storage/Roms -> user/Roms.  Both names must resolve to
# the same accepted tree; the device matrix's explicit root must not be the only
# route that passes containment validation.
user_root=$tmp/user/Roms
compat_root=$tmp/Roms
mkdir -p "$user_root/nes"
ln -s user/Roms "$compat_root"
: >"$user_root/nes/alias-test.nes"
TEST_TRACE=$tmp/alias PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$compat_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=nes \
    "$root/bin/plumos-picoarch-launch" quicknes "$user_root/nes/alias-test.nes"
grep -Fqx 'picoarch=stage-P19 system=nes core=quicknes rc=0' \
    "$root/logs/session.log"

# Canonicalisation must not weaken the traversal boundary: a symlink below the
# ROM root which resolves outside it remains rejected.
: >"$tmp/outside.nes"
ln -s "$tmp/outside.nes" "$user_root/nes/escape.nes"
set +e
TEST_TRACE=$tmp/escape PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$compat_root \
PLUMOS_BIOS_ROOT=$tmp/bios PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox PLUMOS_PICOARCH_SYSTEM=nes \
    "$root/bin/plumos-picoarch-launch" quicknes "$compat_root/nes/escape.nes"
escape_rc=$?
set -e
test "$escape_rc" -eq 2
test ! -e "$tmp/escape.pid"

TEST_TRACE=$tmp/signal TEST_HOLD=1 PLUMOS_ROOT=$root \
PLUMOS_ROM_ROOT=$rom_root PLUMOS_BIOS_ROOT=$tmp/bios \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
PLUMOS_PICOARCH_SYSTEM=nes \
    "$root/bin/plumos-picoarch-launch" quicknes "$rom_root/nes/test.nes" &
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
test -z "$(pidof picoarch 2>/dev/null || true)"
grep -Fqx 'picoarch=stage-P19 system=nes core=quicknes rc=143' \
    "$root/logs/session.log"

echo 'bubble_picoarch_launcher_test=result-ok'
