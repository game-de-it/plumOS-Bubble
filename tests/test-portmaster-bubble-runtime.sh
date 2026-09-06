#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PACKAGE="$ROOT_DIR/package/portmaster-bubble/plumos"
RUNTIME="$PACKAGE/bin/plumos-portmaster-runtime"
GUI_LAUNCH="$PACKAGE/bin/plumos-portmaster-launch"
PORT_LAUNCH="$PACKAGE/bin/plumos-portmaster-port-launch"
MOUNT_CLEANUP="$PACKAGE/bin/plumos-portmaster-mount-cleanup"
FRONTEND_CONTROL="$PACKAGE/bin/plumos-portmaster-frontend-control"
BUILDER="$ROOT_DIR/scripts/build-portmaster-bubble.sh"
UPDATER="$PACKAGE/apps/portmaster/adapter/plumos_portmaster_update.py"
PGREP="$PACKAGE/apps/portmaster/adapter/shims/pgrep"
PKILL="$PACKAGE/apps/portmaster/adapter/shims/pkill"
PATCH_SHIM="$PACKAGE/apps/portmaster/adapter/shims/run-patchscript"
PATCHER_OVERRIDE="$PACKAGE/apps/portmaster/adapter/overrides/patcher.txt"
COMMAND_RUNTIME="$PACKAGE/bin/plumos-portmaster-command-runtime"
SESSION_CLEANUP="$PACKAGE/bin/plumos-portmaster-session-cleanup"
TAR_SHIM="$PACKAGE/apps/portmaster/adapter/shims/tar"
EXEC_GUARD_SOURCE="$ROOT_DIR/package/portmaster-bubble/src/plumos_portmaster_exec_guard.c"

for file in "$RUNTIME" "$GUI_LAUNCH" "$PORT_LAUNCH" "$MOUNT_CLEANUP" "$FRONTEND_CONTROL" "$PGREP" "$PKILL" "$PATCH_SHIM" "$COMMAND_RUNTIME" "$SESSION_CLEANUP" "$TAR_SHIM"; do
    /bin/sh -n "$file"
done

grep -q 'link_one libgthread-2.0.so.0' "$RUNTIME"
grep -q 'link_one libglib-2.0.so.0' "$RUNTIME"
grep -q 'link_one libpcre2-8.so.0' "$RUNTIME"
grep -q 'link_one librt.so.1' "$RUNTIME"
grep -q 'link_one libtinfo.so.6' "$RUNTIME"
grep -q -- "-name 'love.aarch64' -exec chmod 0755" "$RUNTIME"
grep -q 'ctypes.CDLL("libSDL2_mixer-2.0.so.0")' "$GUI_LAUNCH"
grep -q 'PLUMOS_BUBBLE_PYTHON_LD_PRELOAD="$mali_library' "$GUI_LAUNCH"
grep -q 'PLUMOS_BUBBLE_PYTHON_EXTRA_LIBRARY_PATH="${PLUMOS_ROOT}/emulator/lib:${RUN_ROOT}/lib:' "$GUI_LAUNCH"
grep -q 'RESTART_FILE="${PM_DIR}/.pugwash-reboot"' "$GUI_LAUNCH"
grep -q 'restart-marker=stale action=consume' "$GUI_LAUNCH"
grep -q 'restart-marker=requested count=' "$GUI_LAUNCH"
grep -q 'plumos-portmaster-mount-cleanup' "$GUI_LAUNCH" "$PORT_LAUNCH"
grep -q 'plumos-portmaster-frontend-control' "$GUI_LAUNCH" "$PORT_LAUNCH"
grep -q 'plumos-portmaster-command-runtime' "$RUNTIME"
grep -q 'PLUMOS_BUSYBOX:-/bin/busybox.*sh.*COMMAND_RUNTIME' "$RUNTIME"
! grep -q '"$BB" sh "$COMMAND_RUNTIME"' "$RUNTIME"
grep -q 'busybox-bin' "$GUI_LAUNCH" "$PORT_LAUNCH"
! grep -q 'plumos-frontend-stop' "$GUI_LAUNCH" "$PORT_LAUNCH"
grep -q 'libgthread-2.0.so.0:libgthread-2.0.so.0.' "$BUILDER"
grep -q 'ADAPTER_DIR}/shims:${RUN_ROOT}/busybox-bin:${ADAPTER_DIR}/bin/aarch64' "$GUI_LAUNCH"
grep -q 'command -v "$helper"' "$GUI_LAUNCH"
grep -q 'called_by_owned_gptokey' "$PKILL"
grep -q 'plumos-portmaster-port-stop" stop' "$PKILL"
grep -q 'PORT_BASH="${APP_ROOT}/adapter/bin/aarch64/bash"' "$PORT_LAUNCH"
grep -q '^export PORT_BASH$' "$PORT_LAUNCH"
grep -q 'setsid "$PORT_BASH" "$script"' "$PORT_LAUNCH"
grep -q 'PLUMOS_PORTMASTER_REQUIRED_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"' "$PORT_LAUNCH"
grep -q 'PLUMOS_PORTMASTER_REQUIRED_LD_PRELOAD="$EXEC_GUARD_LIB"' "$PORT_LAUNCH"
grep -q 'plumos-portmaster-session-cleanup' "$PORT_LAUNCH"
grep -q 'unset LD_PRELOAD LD_LIBRARY_PATH PLUMOS_PORTMASTER_REQUIRED_LD_PRELOAD' "$PORT_LAUNCH"
grep -q '${PLUMOS_ROOT}/emulator/lib:${PLUMOS_ROOT}/apps/pyxel/lib' "$PORT_LAUNCH"
grep -q 'plumos_portmaster_exec_guard.c' "$BUILDER"
grep -q 'libplumos-portmaster-exec-guard.so' "$BUILDER"
grep -q 'execveat' "$EXEC_GUARD_SOURCE"
grep -q 'posix_spawnp' "$EXEC_GUARD_SOURCE"
grep -q 'prepare_patcher_compat || exit 1' "$PORT_LAUNCH"
grep -q 'PLUMOS_PORTMASTER_PATCH_SCRIPT="$PATCHER_FILE"' "$PATCHER_OVERRIDE"
grep -q 'exec "$PORT_BASH" "$PLUMOS_PORTMASTER_PATCH_SCRIPT"' "$PATCH_SHIM"
grep -q 'BASH_RUNTIME_VERSION="5.2.15-2+b13"' "$BUILDER"
grep -q 'adapter/bin/aarch64/bash' "$BUILDER"
grep -q 'libtinfo.so.6:libtinfo.so.6.' "$BUILDER"
grep -q -- "-name 'love.aarch64'" "$BUILDER"
grep -q 'PortMaster/runtimes/love_\*/love.aarch64' "$UPDATER"
grep -q "! -path 'apps/portmaster/installed.json'" "$BUILDER"

builder_version="$(sed -n 's/^ADAPTER_VERSION="\([0-9][0-9]*\)"$/\1/p' "$BUILDER")"
updater_version="$(sed -n 's/^ADAPTER_VERSION = \([0-9][0-9]*\)$/\1/p' "$UPDATER")"
[ "$builder_version" = "$updater_version" ]

work="$(mktemp -d /tmp/plumos-portmaster-bubble-test.XXXXXX)"
trap 'rm -rf "$work"' EXIT

cat >"$work/busybox" <<'EOF'
#!/bin/sh
case "${1:-}" in
  --list)
    printf '%s\n' basename cat chmod cp df dirname find grep head ln mkdir mv \
      readlink rm sed sha256sum sort sync tail tar tee tr unzip xargs
    ;;
  ln|mkdir|mv|rm) command "$@" ;;
  *) printf '%s\n' "${0##*/}" "$@" ;;
esac
EOF
chmod 0755 "$work/busybox"
command_run="$work/command-run"
PLUMOS_BUSYBOX="$work/busybox" PLUMOS_PORTMASTER_RUN_ROOT="$command_run" \
  "$COMMAND_RUNTIME" >/dev/null
for command_name in basename cp df rm tar tee unzip; do
  [ -x "$command_run/busybox-bin/$command_name" ] || {
    printf 'PortMaster command runtime omitted %s\n' "$command_name" >&2
    exit 1
  }
done
[ "$("$command_run/busybox-bin/df" -PT /roms/ports/Test.sh)" = \
  $'df\n-PT\n/roms/ports/Test.sh' ]

plumos_root="$work/plumos"
run_root="$work/run"
pm_dir="$plumos_root/state/portmaster/data/upstream/PortMaster"
mountinfo="$work/mountinfo"
track="$run_root/port.mounts"
mkdir -p "$run_root" "$pm_dir/config"

write_mountinfo() {
    printf '10 1 0:1 / /usr/lib/compat rw - tmpfs tmpfs rw\n' > "$mountinfo"
    printf '11 1 0:2 / %s/config rw - tmpfs tmpfs rw\n' "$pm_dir" >> "$mountinfo"
}

printf '%s\n' '#!/bin/sh' \
    'lazy=0' \
    'if [ "${1:-}" = -l ]; then lazy=1; shift; fi' \
    'target=$1' \
    'printf "lazy=%s target=%s\n" "$lazy" "$target" >> "$FAKE_UMOUNT_LOG"' \
    'if [ "$target" = "$FAKE_BUSY_TARGET" ] && [ "$lazy" -eq 0 ] && [ ! -f "$FAKE_BUSY_ONCE" ]; then : > "$FAKE_BUSY_ONCE"; exit 1; fi' \
    'awk -v target="$target" '\''$5 != target'\'' "$FAKE_MOUNTINFO" > "$FAKE_MOUNTINFO.tmp"' \
    'mv "$FAKE_MOUNTINFO.tmp" "$FAKE_MOUNTINFO"' > "$work/umount"
chmod 0755 "$work/umount"

mkdir -p "$work/frontend-proc/303"
printf '%s\0%s\0' "$plumos_root/bin/plumos-controller-ui-fbdev" --renderer \
    > "$work/frontend-proc/303/cmdline"
mkdir -p "$work/validation"
[ "$(PLUMOS_ROOT="$plumos_root" \
      PLUMOS_PORTMASTER_PROC_ROOT="$work/frontend-proc" \
      PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
      PLUMOS_FRONTEND_VALIDATION_HOLD="$work/validation/frontend-hold" \
      "$FRONTEND_CONTROL" status)" = 303 ]
printf 'foreign\n' > "$work/validation/frontend-hold"
if PLUMOS_ROOT="$plumos_root" \
   PLUMOS_PORTMASTER_PROC_ROOT="$work/frontend-proc" \
   PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
   PLUMOS_FRONTEND_VALIDATION_HOLD="$work/validation/frontend-hold" \
      "$FRONTEND_CONTROL" acquire >/dev/null 2>&1; then
    printf 'frontend control accepted a foreign validation hold\n' >&2
    exit 1
fi
rm -f "$work/validation/frontend-hold"
printf '%s\n' '#!/bin/sh' \
    'pid=${2:-}' \
    'rm -rf "$FAKE_PROC_ROOT/$pid"' > "$work/frontend-kill"
chmod 0755 "$work/frontend-kill"
printf '%s\n' '#!/bin/sh' \
    ': > "$FAKE_FRONTEND_STARTED"' > "$work/frontend-start"
chmod 0755 "$work/frontend-start"
FAKE_PROC_ROOT="$work/frontend-proc" \
PLUMOS_ROOT="$plumos_root" \
PLUMOS_PORTMASTER_PROC_ROOT="$work/frontend-proc" \
PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
PLUMOS_FRONTEND_VALIDATION_HOLD="$work/validation/frontend-hold" \
PLUMOS_PORTMASTER_KILL_BIN="$work/frontend-kill" \
PLUMOS_PORTMASTER_SLEEP_BIN=true \
    "$FRONTEND_CONTROL" acquire
[ -f "$work/validation/frontend-hold" ]
[ -f "$run_root/frontend-hold.owned" ]
[ ! -d "$work/frontend-proc/303" ]
PLUMOS_ROOT="$plumos_root" \
PLUMOS_PORTMASTER_PROC_ROOT="$work/frontend-proc" \
PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
PLUMOS_FRONTEND_VALIDATION_HOLD="$work/validation/frontend-hold" \
PLUMOS_PORTMASTER_FRONTEND_LAUNCH="$work/frontend-start" \
PLUMOS_PORTMASTER_FRONTEND_START_BIN="$work/frontend-start" \
PLUMOS_PORTMASTER_SLEEP_BIN=true \
FAKE_FRONTEND_STARTED="$work/frontend-started" \
    "$FRONTEND_CONTROL" release
[ ! -e "$work/validation/frontend-hold" ]
[ ! -e "$run_root/frontend-hold.owned" ]
[ -f "$work/frontend-started" ]

mkdir -p "$work/proc/101" "$work/proc/202"
printf 'love.aarch64\0--game\0' > "$work/proc/101/cmdline"
printf 'love.aarch64\n' > "$work/proc/101/comm"
printf 'plumos-controller-ui-fbdev\0--renderer\0fbdev\0' \
    > "$work/proc/202/cmdline"
printf 'plumos-controller-ui-fbdev\n' > "$work/proc/202/comm"
[ "$(PLUMOS_PORTMASTER_PROC_ROOT="$work/proc" "$PGREP" -f 'love[.]aarch64')" = 101 ]
[ "$(PLUMOS_PORTMASTER_PROC_ROOT="$work/proc" "$PGREP" '^plumos-controller')" = 202 ]
if PLUMOS_PORTMASTER_PROC_ROOT="$work/proc" "$PGREP" -f missing >/dev/null; then
    printf 'pgrep shim matched an absent process\n' >&2
    exit 1
fi
if PLUMOS_PORTMASTER_PROC_ROOT="$work/proc" "$PGREP" -x love >/dev/null 2>&1; then
    printf 'pgrep shim accepted an unsupported option\n' >&2
    exit 1
fi

if PLUMOS_ROOT="$plumos_root" PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
   PLUMOS_PORTMASTER_MOUNTINFO="$mountinfo" \
   /bin/sh "$MOUNT_CLEANUP" "$work/unmanaged.track" 2>/dev/null; then
    printf 'mount cleanup accepted an unmanaged tracking file\n' >&2
    exit 1
fi

write_mountinfo
printf '%s\n%s\n%s\n' /usr/lib/compat "$pm_dir/config" / > "$track"
FAKE_UMOUNT_LOG="$work/umount.log" \
FAKE_BUSY_TARGET="$pm_dir/config" \
FAKE_BUSY_ONCE="$work/busy-once" \
FAKE_MOUNTINFO="$mountinfo" \
PLUMOS_ROOT="$plumos_root" \
PLUMOS_PORTMASTER_RUN_ROOT="$run_root" \
PLUMOS_PORTMASTER_MOUNTINFO="$mountinfo" \
PLUMOS_PORTMASTER_UMOUNT_BIN="$work/umount" \
PLUMOS_PORTMASTER_SLEEP_BIN=true \
    /bin/sh "$MOUNT_CLEANUP" "$track"

[ ! -s "$mountinfo" ]
[ ! -e "$track" ]
grep -q "target=/usr/lib/compat" "$work/umount.log"
grep -q "target=$pm_dir/config" "$work/umount.log"
! grep -q 'target=/$' "$work/umount.log"

printf 'portmaster_bubble_runtime=result-ok adapter=%s command_runtime=busybox-all exec_guard=1 session_cleanup=1 xz_tar=1 gui_preflight=1 mali_preload=1 pgrep=1 frontend_handoff=1 frontend_restore=1 restart=1 mount_recovery=1\n' \
    "$builder_version"
