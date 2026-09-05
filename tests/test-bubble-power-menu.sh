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
frontend=$repo_root/src/frontend/plumos_controller_ui.c
drm_master=$repo_root/src/services/plumos_drm_master.c
drm_broker=$repo_root/src/services/plumos_drm_broker_run.c
drm_share=$repo_root/src/services/plumos_drm_share.c
retroarch_launch=$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-launch
retroarch_menu=$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-menu-launch
picoarch_launch=$repo_root/package/picoarch-bubble/plumos/bin/plumos-picoarch-launch
standalone_launch=$repo_root/package/standalone-bubble/plumos/bin/plumos-standalone-launch

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
printf 'action=%s\n' "${TEST_SELECTION:-cancel}" >"${PLUMOS_POWER_MENU_SELECTION:?}"
printf '%s\n' "$*" >"${TEST_MENU_ARGS:?}"
[ -z "${TEST_POWER_TRACE:-}" ] || printf 'menu:%s\n' "${TEST_SELECTION:-cancel}" >>"$TEST_POWER_TRACE"
EOF
cat >"$root/bin/plumos-safe-shutdown" <<'EOF'
#!/bin/sh
[ -z "${TEST_POWER_TRACE:-}" ] || printf 'safe:%s\n' "$*" >>"$TEST_POWER_TRACE"
exit 0
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

# Terminal actions must destroy the active game/app before safe shutdown.
cat >"$root/bin/fake-quiesce" <<'EOF'
#!/bin/sh
printf 'quiesce:%s\n' "$*" >>"${TEST_POWER_TRACE:?}"
case $1 in
    hold) : >"$2" ;;
    terminate) rm -f "$2" "$3" ;;
    terminate-state) : ;;
    release) rm -f "$2" ;;
esac
EOF
chmod 0755 "$root/bin/fake-quiesce"
: >"$tmp/terminal.trace"
TEST_SELECTION=shutdown TEST_POWER_TRACE=$tmp/terminal.trace \
TEST_MENU_ARGS=$tmp/terminal-menu.args PLUMOS_ROOT=$root \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_POWER_MENU_OVERLAY_LOG=$tmp/terminal.log \
PLUMOS_POWER_MENU_QUIESCE=$root/bin/fake-quiesce \
    "$root/bin/plumos-power-menu-overlay" open
sed -n '1p' "$tmp/terminal.trace" | grep -q '^quiesce:hold '
sed -n '2p' "$tmp/terminal.trace" | grep -q '^menu:shutdown$'
sed -n '3p' "$tmp/terminal.trace" | grep -q '^quiesce:terminate '
sed -n '4p' "$tmp/terminal.trace" | grep -q '^safe:--shutdown '
sed -n '5p' "$tmp/terminal.trace" | grep -q '^quiesce:terminate-state '

# The real quiesce helper must terminate a dedicated process group, escalating
# as needed, and separately catch storage users with no display descriptor.
marker=$runtime/frontend/foreground.pgid
mkdir -p "${marker%/*}" "$tmp/storage/user"
/bin/busybox setsid /bin/busybox sleep 30 &
group_pid=$!
printf 'pgid=%s\n' "$group_pid" >"$marker"
"$root/bin/plumos-runtime-quiesce" terminate-active "$marker" \
    >"$tmp/group.log" 2>&1 &
quiesce_pid=$!
wait "$group_pid" 2>/dev/null || true
wait "$quiesce_pid"
test ! -e "$marker"
grep -q 'label=foreground-group.*signal=TERM' "$tmp/group.log"

ready=$tmp/stubborn.ready
/bin/busybox setsid /bin/busybox sh -c \
    'trap "" TERM; : >"$1"; exec /bin/busybox sleep 30' sh "$ready" &
stubborn_pid=$!
while [ ! -e "$ready" ]; do /bin/busybox usleep 10000; done
printf 'pgid=%s\n' "$stubborn_pid" >"$marker"
"$root/bin/plumos-runtime-quiesce" terminate-active "$marker" \
    >"$tmp/stubborn.log" 2>&1 &
quiesce_pid=$!
wait "$stubborn_pid" 2>/dev/null || true
wait "$quiesce_pid"
grep -q 'label=foreground-group.*signal=KILL' "$tmp/stubborn.log"

printf 'busy\n' >"$tmp/storage/user/rom.bin"
/bin/busybox setsid /bin/busybox sh -c \
    'exec 3<"$1"; exec /bin/busybox sleep 30' sh \
    "$tmp/storage/user/rom.bin" &
storage_pid=$!
"$root/bin/plumos-runtime-quiesce" terminate-storage "$tmp/storage/user" \
    >"$tmp/storage.log" 2>&1 &
quiesce_pid=$!
wait "$storage_pid" 2>/dev/null || true
wait "$quiesce_pid"
grep -q 'label=storage-blocker.*signal=TERM' "$tmp/storage.log"

/bin/busybox sleep 30 &
state_pid=$!
printf 'pid=%s\n' "$state_pid" >"$tmp/frontend.ready"
"$root/bin/plumos-runtime-quiesce" terminate-state "$tmp/frontend.ready" \
    >"$tmp/state.log" 2>&1 &
quiesce_pid=$!
wait "$state_pid" 2>/dev/null || true
wait "$quiesce_pid"
grep -q 'label=state-owner.*signal=TERM' "$tmp/state.log"

grep -Fq '/dev/fb0|/dev/dri/*|/dev/mali*|/dev/disp' "$quiesce"
grep -Fq '"$DRM_MASTER" drop "$pid"' "$quiesce"
grep -Fq '"$DRM_MASTER" set "$pid"' "$quiesce"
grep -q 'src/services/plumos_drm_master.c' "$build"
grep -q 'plumos-power-menu-overlay' "$build"
grep -q 'frontend/foreground.pgid' \
    "$repo_root/src/frontend/plumos_controller_ui.c"
grep -q 'plumos-drm-broker-run' "$frontend"
grep -q 'libplumos-drm-share.so' "$frontend"
grep -q 'SCM_RIGHTS' "$drm_share"
grep -q 'DRM_IOCTL_DROP_MASTER' "$drm_broker"
grep -q 'drm-handoff' "$drm_master"
grep -q 'plumos-drm-brok' "$quiesce"
grep -q 'PLUMOS_DRM_SHARE_LIBRARY' "$retroarch_launch"
grep -q 'PLUMOS_DRM_SHARE_LIBRARY' "$retroarch_menu"
grep -q 'PLUMOS_DRM_SHARE_LIBRARY' "$picoarch_launch"
test "$(grep -c 'LD_PRELOAD=' "$standalone_launch")" -eq 5
grep -q 'mali_preload=.*drm_share_preload' "$standalone_launch"
grep -q 'terminate-storage.*"$USER_MOUNT"' \
    "$repo_root/package/frontend-bubble/plumos/bin/plumos-safe-shutdown"
grep -q 'terminate-state' "$overlay"
grep -q '"$FRONTEND_READY"' "$overlay"

printf 'bubble_power_menu=result-ok policy=frontend-delegate,foreground-drm-handoff\n'
