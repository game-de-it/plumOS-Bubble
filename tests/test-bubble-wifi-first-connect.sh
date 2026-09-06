#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
network_control=${1:-$repo_root/package/frontend-bubble/plumos/bin/plumos-network-control}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bubble-wifi-first-connect.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

root=$tmp/root
run=$tmp/run
sys_net=$tmp/sys/class/net
mock=$tmp/mock
mkdir -p "$root/config" "$run" "$sys_net/wlan0" "$mock"

cat >"$mock/busybox" <<'EOF'
#!/bin/sh
set -eu
command=$1
shift
case "$command" in
    ip) exit 0 ;;
    sleep) exit 0 ;;
    *) exec "$command" "$@" ;;
esac
EOF

cat >"$mock/wpa_cli" <<'EOF'
#!/bin/sh
set -eu
command=
for argument in "$@"; do
    case "$argument" in
        ping|scan|scan_results|status|signal_poll) command=$argument ;;
    esac
done
case "$command" in
    ping)
        [ -f "$MOCK_WPA_READY_FILE" ] || exit 1
        printf 'PONG\n'
        ;;
    scan) ;;
    scan_results)
        printf 'bssid / frequency / signal level / flags / ssid\n'
        printf '00:11:22:33:44:55\t2412\t-42\t[WPA2-PSK-CCMP][ESS]\tk-home-test\n'
        ;;
    status) printf 'wpa_state=DISCONNECTED\n' ;;
    signal_poll) ;;
    *) exit 2 ;;
esac
EOF

cat >"$mock/wpa_supplicant" <<'EOF'
#!/bin/sh
set -eu
config=
previous=
for argument in "$@"; do
    if [ "$previous" = -c ]; then
        config=$argument
        break
    fi
    previous=$argument
done
[ -n "$config" ] || exit 2
printf '%s\n' "$config" >"$MOCK_WPA_CONFIG_ARGUMENT"
: >"$MOCK_WPA_READY_FILE"
EOF
chmod 0755 "$mock/busybox" "$mock/wpa_cli" "$mock/wpa_supplicant"

run_scan() {
    MOCK_WPA_READY_FILE=$mock/ready \
    MOCK_WPA_CONFIG_ARGUMENT=$mock/config-argument \
    PLUMOS_ROOT=$root \
    PLUMOS_RUNTIME_ROOT=$run \
    PLUMOS_BUSYBOX=$mock/busybox \
    PLUMOS_WIFI_SYS_CLASS_NET=$sys_net \
    PLUMOS_WPA_SUPPLICANT=$mock/wpa_supplicant \
    PLUMOS_WPA_CLI=$mock/wpa_cli \
    PLUMOS_WPA_CTRL_DIR=$run/wpa_supplicant \
    PLUMOS_WPA_PID_FILE=$run/wpa_supplicant.pid \
    PLUMOS_WPA_CONTROL_WAIT_SECONDS=1 \
    PLUMOS_NETWORK_LOG=$root/logs/network-control.log \
        sh "$network_control" --scan
}

# A new image has no saved SSID or PSK.  The scan must create only a private
# runtime config and must not create a persistent credential file.
output=$(run_scan)
expected_row=$(printf 'network\tsecured\t-42\tk-home-test')
printf '%s\n' "$output" | grep -Fqx "$expected_row"
test ! -e "$root/config/wpa_supplicant.conf"
test -f "$run/network-control/wpa-scan.conf"
cat >"$tmp/expected-scan.conf" <<EOF
ctrl_interface=$run/wpa_supplicant
update_config=0
country=JP
EOF
cmp "$tmp/expected-scan.conf" "$run/network-control/wpa-scan.conf"
mode=$(stat -c %a "$run/network-control/wpa-scan.conf" 2>/dev/null || \
    stat -f %Lp "$run/network-control/wpa-scan.conf")
test "$mode" = 600
test "$(sed -n '1p' "$mock/config-argument")" = \
    "$run/network-control/wpa-scan.conf"
grep -Fq 'config=runtime-only' "$root/logs/network-control.log"

# Once a saved configuration exists, it remains the backend input and the
# runtime-only file is not recreated.
rm -f "$mock/ready" "$mock/config-argument" \
    "$run/network-control/wpa-scan.conf"
cat >"$root/config/wpa_supplicant.conf" <<EOF
ctrl_interface=$run/wpa_supplicant
update_config=0
country=JP
network={}
EOF
chmod 0600 "$root/config/wpa_supplicant.conf"
output=$(run_scan)
printf '%s\n' "$output" | grep -Fqx "$expected_row"
test ! -e "$run/network-control/wpa-scan.conf"
test "$(sed -n '1p' "$mock/config-argument")" = \
    "$root/config/wpa_supplicant.conf"
grep -Fq 'config=saved' "$root/logs/network-control.log"

echo 'bubble_wifi_first_connect_test=result-ok credential_free_scan=yes saved_config_preserved=yes'
