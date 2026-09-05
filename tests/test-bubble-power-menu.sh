#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [ "${1:-}" != --inside ]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./tests/test-bubble-power-menu.sh --inside
fi
overlay=$repo_root/package/frontend-bubble/plumos/bin/plumos-power-menu-overlay
quiesce=$repo_root/package/frontend-bubble/plumos/bin/plumos-runtime-quiesce
build=$repo_root/scripts/build-bubble-frontend.sh

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
runtime=$tmp/run
mkdir -p "$root/bin" "$root/logs" "$runtime"
cp "$overlay" "$quiesce" "$root/bin/"
chmod 0755 "$root/bin/plumos-power-menu-overlay" \
    "$root/bin/plumos-runtime-quiesce"
cat >"$root/bin/plumos-controller-ui-bubble" <<'EOF'
#!/bin/sh
printf 'action=cancel\n' >"${PLUMOS_POWER_MENU_SELECTION:?}"
printf '%s\n' "$*" >"${TEST_MENU_ARGS:?}"
EOF
cat >"$root/bin/plumos-safe-shutdown" <<'EOF'
#!/bin/sh
exit 99
EOF
chmod 0755 "$root/bin/plumos-controller-ui-bubble" \
    "$root/bin/plumos-safe-shutdown"

PLUMOS_ROOT=$root PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_POWER_MENU_OVERLAY_LOG=$tmp/overlay.log \
PLUMOS_DISPLAY_OWNER_PIDS='' TEST_MENU_ARGS=$tmp/menu.args \
    "$root/bin/plumos-power-menu-overlay" open
grep -q '^--power-overlay$' "$tmp/menu.args"
grep -q 'menu end rc=0 selection=cancel' "$tmp/overlay.log"
test ! -e "$runtime/power-menu-overlay.lock"
test ! -e "$runtime"/*.quiesce

grep -Fq '/dev/fb0|/dev/dri/*|/dev/mali*|/dev/disp' "$quiesce"
grep -Fq '"$DRM_MASTER" drop "$pid"' "$quiesce"
grep -Fq '"$DRM_MASTER" set "$pid"' "$quiesce"
grep -q 'src/services/plumos_drm_master.c' "$build"
grep -q 'plumos-power-menu-overlay' "$build"

printf 'bubble_power_menu=result-ok policy=frontend-delegate,foreground-drm-handoff\n'
