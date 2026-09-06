#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
finalizer=$repo_root/package/frontend-bubble/plumos/bin/plumos-power-request-finalizer
shutdown=$repo_root/package/frontend-bubble/plumos/bin/plumos-safe-shutdown
init=$repo_root/rootfs/bubble-frontend/init

sh -n "$finalizer" "$shutdown" "$init"
grep -q 'plumos-power-request-finalizer' "$shutdown"
grep -q 'stage=power-fallback result=armed' "$shutdown"
grep -q 'S43_FRONTEND_INTENTIONAL_HOLD restart-budget=preserved' "$init"
grep -q 'S88_RECOVERY_POWER_WATCH_READY' "$init"
grep -q 'S89_RECOVERY_POWER_REQUEST' "$init"
grep -q 'S90_POWER_FINALIZE_ALREADY_CLAIMED' "$init"

work=$(mktemp -d /tmp/plumos-power-finalizer-test.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/run/power-action" "$work/plumos/logs"
printf 'shutdown\n' > "$work/run/power-action/request"
: > "$work/mounts"

cat > "$work/backend" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" > "$FAKE_POWER_RESULT"
EOF
chmod 0755 "$work/backend"
cat > "$work/busybox" <<'EOF'
#!/bin/sh
command_name=${1:-}
shift || true
case "$command_name" in
    mount) exit 1 ;;
    sync) sync ;;
    *) exec "$command_name" "$@" ;;
esac
EOF
chmod 0755 "$work/busybox"

PLUMOS_ROOT="$work/plumos" \
PLUMOS_RUNTIME_ROOT="$work/run" \
PLUMOS_BUSYBOX="$work/busybox" \
PLUMOS_POWER_REQUEST="$work/run/power-action/request" \
PLUMOS_POWER_FINALIZE_CLAIM="$work/run/power-action/finalizing" \
PLUMOS_POWER_FINALIZE_WAIT_SECONDS=0 \
PLUMOS_POWER_BACKEND="$work/backend" \
PLUMOS_MOUNTS_FILE="$work/mounts" \
FAKE_POWER_RESULT="$work/result" \
    sh "$finalizer" shutdown

[ "$(cat "$work/result")" = shutdown ]
[ ! -e "$work/run/power-action/request" ]
grep -q 'stage=S92_POWER_FALLBACK_BEGIN action=shutdown wait_seconds=0' \
    "$work/plumos/logs/power-action.log"

rm -rf "$work/run/power-action/finalizing"
printf 'reboot\n' > "$work/run/power-action/request"
PLUMOS_ROOT="$work/plumos" \
PLUMOS_RUNTIME_ROOT="$work/run" \
PLUMOS_BUSYBOX="$work/busybox" \
PLUMOS_POWER_REQUEST="$work/run/power-action/request" \
PLUMOS_POWER_FINALIZE_CLAIM="$work/run/power-action/finalizing" \
PLUMOS_POWER_FINALIZE_WAIT_SECONDS=0 \
PLUMOS_POWER_BACKEND="$work/backend" \
PLUMOS_MOUNTS_FILE="$work/mounts" \
FAKE_POWER_RESULT="$work/unexpected" \
    sh "$finalizer" shutdown
[ ! -e "$work/unexpected" ]
[ "$(cat "$work/run/power-action/request")" = reboot ]

printf 'bubble_power_request_finalizer=result-ok pid1=preferred fallback=bounded recovery=watched\n'
