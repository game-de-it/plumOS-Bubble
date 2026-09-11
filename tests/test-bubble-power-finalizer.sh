#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
finalizer=$repo_root/package/frontend-bubble/plumos/bin/plumos-power-request-finalizer
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/root/bin" "$tmp/root/provision" "$tmp/run/power-action" \
    "$tmp/user" "$tmp/bin"
cp "$repo_root/package/frontend-bubble/plumos/bin/plumos-runtime-quiesce" \
    "$tmp/root/bin/plumos-runtime-quiesce"
chmod 0755 "$tmp/root/bin/plumos-runtime-quiesce"

cat >"$tmp/bin/busybox" <<'EOF'
#!/bin/sh
command_name=$1
shift
case "$command_name" in
    mount)
        printf 'mount %s\n' "$*" >>"$PLUMOS_TEST_CALLS"
        case "${PLUMOS_TEST_REMOUNT_RESULT:-ok}:$*" in
            failed:'-o remount,ro /storage') exit 1 ;;
        esac
        exit 0
        ;;
    reboot|poweroff)
        printf '%s %s\n' "$command_name" "$*" >>"$PLUMOS_TEST_CALLS"
        exit 0
        ;;
    sync) exit 0 ;;
    *) exec "$command_name" "$@" ;;
esac
EOF
chmod 0755 "$tmp/bin/busybox"

cat >"$tmp/root/bin/fake-quiesce" <<'EOF'
#!/bin/sh
printf 'quiesce %s\n' "$*" >>"$PLUMOS_TEST_CALLS"
exit 0
EOF
chmod 0755 "$tmp/root/bin/fake-quiesce"

run_finalizer() {
    result=$1
    : >"$tmp/calls-$result"
    printf 'reboot\n' >"$tmp/run/power-action/request"
    printf '/dev/testp4\n' >"$tmp/run/power-action/user-source"
    : >"$tmp/root/provision/clean-shutdown"
    PLUMOS_ROOT="$tmp/root" \
    PLUMOS_RUNTIME_ROOT="$tmp/run" \
    PLUMOS_BUSYBOX="$tmp/bin/busybox" \
    PLUMOS_POWER_REQUEST="$tmp/run/power-action/request" \
    PLUMOS_POWER_FINALIZE_CLAIM="$tmp/run/power-action/finalizing" \
    PLUMOS_POWER_ACTION_LOG="$tmp/power-$result.log" \
    PLUMOS_MOUNTS_FILE="$tmp/mounts" \
    PLUMOS_USER_MOUNT="$tmp/user" \
    PLUMOS_USER_SOURCE_FILE="$tmp/run/power-action/user-source" \
    PLUMOS_RUNTIME_QUIESCE="$tmp/root/bin/fake-quiesce" \
    PLUMOS_POWER_FINALIZE_WAIT_SECONDS=0 \
    PLUMOS_TEST_CALLS="$tmp/calls-$result" \
    PLUMOS_TEST_REMOUNT_RESULT="$result" \
        sh "$finalizer" reboot
}

: >"$tmp/mounts"
run_finalizer ok
grep -qx 'quiesce terminate-storage /storage' "$tmp/calls-ok"
grep -qx 'mount -o remount,ro /storage' "$tmp/calls-ok"
grep -qx 'reboot -f' "$tmp/calls-ok"
test "$(sed -n '1p' "$tmp/calls-ok")" = 'quiesce terminate-storage /storage'

if run_finalizer failed; then
    echo 'failed remount unexpectedly succeeded' >&2
    exit 1
fi
grep -qx 'quiesce terminate-storage /storage' "$tmp/calls-failed"
grep -qx "mount -t vfat -o rw,noatime /dev/testp4 $tmp/user" \
    "$tmp/calls-failed"
grep -q 'user-storage=recovered' "$tmp/power-failed.log"
test ! -e "$tmp/root/provision/clean-shutdown"

printf '%s\n' 'bubble_power_finalizer=result-ok fallback_quiesce=yes refusal_recovers_p4=yes'
