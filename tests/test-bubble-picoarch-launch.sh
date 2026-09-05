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
    "$root/emulator/lib" "$root/cores" "$root/share/alsa" \
    "$rom_root/nes" "$runtime"
cp package/picoarch-bubble/plumos/bin/plumos-picoarch-launch \
    "$root/bin/plumos-picoarch-launch"
: >"$root/cores/quicknes_libretro.so"
: >"$root/share/alsa/alsa.conf"
: >"$rom_root/nes/test.nes"
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
