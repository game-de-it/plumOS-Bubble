#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
safe=$repo_root/package/frontend-bubble/plumos/bin/plumos-safe-shutdown
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

root=$tmp/root
run=$tmp/run
mkdir -p "$root/bin" "$root/config/system" "$run" "$tmp/wlan0"
printf '{"wifi_enabled": true}\n' >"$root/config/system/settings.json"
printf 'freeze mem\n' >"$tmp/power-state"
: >"$tmp/wakealarm"

cat >"$tmp/fake-busybox" <<'EOF'
#!/bin/sh
command_name=$1
shift
case "$command_name" in
    sync) exit 0 ;;
    sleep) exit 0 ;;
    *) exec "$command_name" "$@" ;;
esac
EOF
chmod +x "$tmp/fake-busybox"

cat >"$root/bin/plumos-network-control" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$PLUMOS_TEST_NETWORK_CALLS"
case "$*" in *'--wifi on'*) printf 'result=connected\n' ;; *) printf 'result=off\n' ;; esac
EOF
cat >"$root/bin/plumos-network-services" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$PLUMOS_TEST_SERVICE_CALLS"
EOF
cat >"$root/bin/plumos-volume-control" <<'EOF'
#!/bin/sh
case ${1:-} in get) printf '7\n' ;; apply) printf '%s\n' "$*" >>"$PLUMOS_TEST_VOLUME_CALLS" ;; esac
EOF
cat >"$root/bin/plumos-display-control" <<'EOF'
#!/bin/sh
case ${1:-} in get) printf '11\n' ;; apply) printf '%s\n' "$*" >>"$PLUMOS_TEST_DISPLAY_CALLS" ;; esac
EOF
chmod +x "$root/bin/"*

export PLUMOS_ROOT=$root
export PLUMOS_RUNTIME_ROOT=$run
export PLUMOS_BUSYBOX=$tmp/fake-busybox
export PLUMOS_POWER_STATE=$tmp/power-state
export PLUMOS_RTC_WAKEALARM=$tmp/wakealarm
export PLUMOS_WIFI_INTERFACE_PATH=$tmp/wlan0
export PLUMOS_TEST_NETWORK_CALLS=$tmp/network.calls
export PLUMOS_TEST_SERVICE_CALLS=$tmp/service.calls
export PLUMOS_TEST_VOLUME_CALLS=$tmp/volume.calls
export PLUMOS_TEST_DISPLAY_CALLS=$tmp/display.calls

sh "$safe" --sleep --sleep-backend mem --wakeup-sec 8 >"$tmp/result"
grep -q '^result=resumed action=sleep backend=mem$' "$tmp/result"
grep -qx -- '--wifi off' "$tmp/network.calls"
for _ in {1..20}; do
    grep -qx -- '--wifi on' "$tmp/network.calls" 2>/dev/null && break
    sleep 0.05
done
grep -qx -- '--wifi on' "$tmp/network.calls"
grep -qx 'start-enabled' "$tmp/service.calls"
grep -qx 'apply 7' "$tmp/volume.calls"
grep -qx 'apply 11' "$tmp/display.calls"
grep -qx 'mem' "$tmp/power-state"

printf 'freeze mem\n' >"$tmp/power-state"
: >"$tmp/network.calls"
printf '{"wifi_enabled": false}\n' >"$root/config/system/settings.json"
sh "$safe" --sleep --sleep-backend mem >"$tmp/disabled.result"
if [[ -s $tmp/network.calls ]]; then exit 1; fi

printf 'bubble_sleep=result-ok backend=mem wifi=paused-restored-background rtc=bounded\n'
