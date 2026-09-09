#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
package="$repo_root/package/frontend-bubble/plumos"
menus="$package/config/frontend/menus.json"
apps="$package/config/frontend/apps.json"
coverage="$package/config/frontend/start-menu-coverage.json"
system_defaults="$package/factory-defaults/system/settings.json"
gg_boxart_rescue="$package/share/frontend/artwork-scraper/rescue/gamegear/Named_Boxarts.tsv"
gg_title_rescue="$package/share/frontend/artwork-scraper/rescue/gamegear/Named_Titles.tsv"

expected_start='["ui-settings","system-settings","network-settings","performance-settings","apps","help","reboot","shutdown"]'
expected_apps='["scraping","file_manager","music_player","retroarch","pyxel_setup","portmaster","portmaster_update","ggfe"]'
expected_apps_catalog='["scraping","file_manager","music_player","retroarch","pyxel_setup","portmaster","portmaster_update","thumbnail-plan","thumbnail-fetch","thumbnail-results","ggfe"]'
expected_apps_hidden='["thumbnail-plan","thumbnail-fetch","thumbnail-results"]'
expected_legacy_hidden='["settings","network"]'

if [[ $(jq -c '[.menus[] | select(.id == "start") | .entries[].id]' "$menus") != "$expected_start" ]]; then exit 1; fi
if [[ $(jq -c '[.apps[] | select(.menu == "apps" and .visible != false) | .id]' "$apps") != "$expected_apps" ]]; then exit 1; fi
if [[ $(jq -c '[.apps[] | select(.menu == "apps") | .id]' "$apps") != "$expected_apps_catalog" ]]; then exit 1; fi
if [[ $(jq -c '[.apps[] | select(.menu == "apps" and .visible == false) | .id]' "$apps") != "$expected_apps_hidden" ]]; then exit 1; fi
if [[ $(jq -c '[.apps[] | select(.menu == "start" and .visible == false) | .id]' "$apps") != "$expected_legacy_hidden" ]]; then exit 1; fi
if [[ $(jq -c '.start_order' "$coverage") != "$expected_start" ]]; then exit 1; fi
if [[ $(jq -c '.apps_order' "$coverage") != "$expected_apps" ]]; then exit 1; fi
if [[ $(jq -c '.apps_catalog_order' "$coverage") != "$expected_apps_catalog" ]]; then exit 1; fi
if [[ $(jq -c '.apps_hidden_order' "$coverage") != "$expected_apps_hidden" ]]; then exit 1; fi
if [[ $(jq -c '.legacy_hidden_order' "$coverage") != "$expected_legacy_hidden" ]]; then exit 1; fi
jq -e '.language == "en.lang"' "$system_defaults" >/dev/null
# GGFE is the Game Gear frontend and exists only on Bubble; it is tracked
# here rather than added to the common plumOS apps list.
jq -e '.bubble_only_start_entries == [] and .bubble_only_apps_entries == ["ggfe"]' "$coverage" >/dev/null
jq -e 'all(.start_entries[]; .status == "implemented") and
    all(.apps_entries[]; .status == "implemented") and
    ([.apps_entries[] | select(.visible == true) | .id] == .apps_order) and
    ([.apps_entries[] | select(.visible == false) | .id] == .apps_hidden_order)' \
    "$coverage" >/dev/null
jq -e '[.implemented_subroutes[].path] == [
    "system/lumination",
    "system/display-color",
    "system/update/runtime",
    "system/factory-reset/picoarch",
    "network/services/ftp",
    "network/services/sftp",
    "network/services/samba"
  ] and
  ([.unsupported_visible[].path] | index("network/services/ftp") == null) and
  ([.unsupported_visible[].path] | index("network/services/sftp") == null) and
  ([.unsupported_visible[].path] | index("network/services/samba") == null) and
  ([.unsupported_visible[].path] | index("system/lumination") == null) and
  ([.unsupported_visible[].path] | index("system/display-color") == null) and
  ([.unsupported_visible[].path] | index("system/update/runtime") == null) and
  ([.unsupported_visible[].path] | index("system/factory-reset/picoarch") == null) and
  ([.unsupported_visible[].path] | index("network/services/adb") == null) and
  ([.product_excluded[] | select(.visible == false) | .path] ==
    ["network/services/adb", "display/hdmi"])' \
    "$coverage" >/dev/null

for id in scraping file_manager music_player retroarch pyxel_setup portmaster \
    portmaster_update thumbnail-plan thumbnail-fetch thumbnail-results ggfe; do
    jq -e --arg id "$id" '.apps[] | select(.id == $id) | (.available // true) == true' "$apps" >/dev/null
done

for lang in "$package"/share/frontend/lang/*.lang; do
    grep -q '^common.not_supported=' "$lang"
    grep -q '^common.not_supported_on_device=' "$lang"
    grep -q '^common.start=' "$lang"
    grep -q '^common.stop=' "$lang"
    grep -q '^common.unavailable=' "$lang"
done

grep -Fq 'PLUMOS_BUSYBOX="$BB"' "$package/bin/plumos-frontend-launch"
grep -Fq 'PLUMOS_BUSYBOX="$BB"' "$package/bin/plumos-controller-ui-bubble"
if [[ $(wc -l < "$gg_boxart_rescue") -ne 2 ]]; then exit 1; fi
if [[ $(wc -l < "$gg_title_rescue") -ne 2 ]]; then exit 1; fi
grep -q $'^04302bbd\tEternal%20Legend' "$gg_boxart_rescue"
grep -q $'^407ac070\tPutt%20_%20Putter' "$gg_boxart_rescue"
cmp "$gg_boxart_rescue" "$gg_title_rescue"
grep -Fq 'tr(ui, "common.start", "Start")' \
    "$repo_root/src/frontend/plumos_controller_ui.c"
grep -Fq 'tr(ui, "common.stop", "Stop")' \
    "$repo_root/src/frontend/plumos_controller_ui.c"
grep -Fq 'copy_string(busybox, sizeof(busybox), "/bin/busybox")' \
    "$repo_root/src/frontend/plumos_controller_ui.c"
network_service_entries=$(sed -n \
    '/^static void add_network_service_entries/,/^}/p' \
    "$repo_root/src/frontend/plumos_controller_ui.c")
network_information_entries=$(sed -n \
    '/^static void add_network_information_entries/,/^}/p' \
    "$repo_root/src/frontend/plumos_controller_ui.c")
! grep -q 'add_unavailable_setting_entry(ui, "network_adb_enabled"' \
    <<<"$network_service_entries"
grep -q 'if (!runtime_device_is_bubble())' <<<"$network_information_entries"
grep -q 'add_setting_entry(ui, "network_adb_status"' \
    <<<"$network_information_entries"

for helper in plumos-display-control plumos-network-control plumos-network-services \
    plumos-time-sync plumos-factory-reset plumos-safe-shutdown \
    plumos-thumbnail-scraper plumos-system-update plumos-openssl; do
    sh -n "$package/bin/$helper"
done

network_control="$package/bin/plumos-network-control"
scan_body=$(sed -n '/^scan_networks()/,/^}/p' "$network_control")
connect_body=$(sed -n '/^connect_file()/,/^}/p' "$network_control")
wifi_on_body=$(sed -n '/^wifi_on()/,/^}/p' "$network_control")
grep -q 'ensure_wpa_backend' <<<"$scan_body"
grep -q 'ensure_wpa_backend' <<<"$connect_body"
! grep -q 'wifi_on' <<<"$scan_body"
! grep -q 'wifi_on' <<<"$connect_body"
grep -q 'association=not-required' "$network_control"
grep -q 'config_has_network' <<<"$wifi_on_body"
grep -q 'write_scan_config' "$network_control"
grep -q 'config_source=runtime-only' "$network_control"
"$repo_root/tests/test-bubble-wifi-first-connect.sh" "$network_control"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/root/config/system" "$tmp/run" "$tmp/backlight"
printf '{"brightness": 10}\n' >"$tmp/root/config/system/settings.json"
printf '0\n' >"$tmp/backlight/brightness"
printf '255\n' >"$tmp/backlight/max_brightness"
PLUMOS_ROOT="$tmp/root" PLUMOS_RUNTIME_ROOT="$tmp/run" \
PLUMOS_BUBBLE_BACKLIGHT="$tmp/backlight/brightness" \
PLUMOS_BUBBLE_MAX_BRIGHTNESS="$tmp/backlight/max_brightness" \
    sh "$package/bin/plumos-display-control" apply 20
if [[ $(cat "$tmp/backlight/brightness") != 255 ]]; then exit 1; fi
grep -q '"brightness": 10' "$tmp/root/config/system/settings.json"

mkdir -p "$tmp/factory/retroarch" "$tmp/factory/picoarch/config/standalone" \
    "$tmp/factory/standalone/ppsspp/PSP/SYSTEM" \
    "$tmp/factory/standalone/yabasanshiro" "$tmp/factory/standalone/pcsx_rearmed"
printf 'ra\n' >"$tmp/factory/retroarch/retroarch.cfg"
printf 'PLUMOS_PICOARCH_EFFECT=NONE\n' >"$tmp/factory/picoarch/config/standalone/picoarch.env"
printf 'ppsspp\n' >"$tmp/factory/standalone/ppsspp/PSP/SYSTEM/ppsspp.ini"
printf 'controls\n' >"$tmp/factory/standalone/ppsspp/PSP/SYSTEM/controls.ini"
printf '{}\n' >"$tmp/factory/standalone/yabasanshiro/keymapv2.json"
printf 'pcsx\n' >"$tmp/factory/standalone/pcsx_rearmed/pcsx.cfg"
PLUMOS_ROOT="$tmp/root" PLUMOS_FACTORY_DEFAULTS_ROOT="$tmp/factory" \
    sh "$package/bin/plumos-factory-reset" all --dry-run >"$tmp/factory.log"
grep -q 'would restore ra: config/retroarch/retroarch.cfg' "$tmp/factory.log"
grep -q 'would restore pico: config/standalone/picoarch.env' "$tmp/factory.log"
grep -q 'would restore sa: config/standalone/ppsspp/ppsspp/PSP/SYSTEM/ppsspp.ini' "$tmp/factory.log"

PLUMOS_ROOT="$tmp/root" PLUMOS_RUNTIME_ROOT="$tmp/run" \
    sh "$package/bin/plumos-safe-shutdown" --reboot --dry-run >"$tmp/power.log"
grep -q 'result=dry-run action=reboot' "$tmp/power.log"
grep -q 'user=/storage/user' "$tmp/power.log"
grep -q 'clean-shutdown' "$package/bin/plumos-safe-shutdown"

mkdir -p "$tmp/power-root/provision" "$tmp/power-user" "$tmp/power-runtime"
printf '/dev/testp4 %s vfat rw 0 0\n' "$tmp/power-user" >"$tmp/mounts"
cat >"$tmp/fake-busybox" <<'EOF'
#!/bin/sh
command_name=$1
shift
case "$command_name" in
    mount|umount|sync|reboot|poweroff)
        printf '%s %s\n' "$command_name" "$*" >>"$PLUMOS_TEST_POWER_CALLS"
        exit 0
        ;;
    *) exec "$command_name" "$@" ;;
esac
EOF
chmod +x "$tmp/fake-busybox"
PLUMOS_ROOT="$tmp/power-root" \
PLUMOS_RUNTIME_ROOT="$tmp/power-runtime" \
PLUMOS_USER_MOUNT="$tmp/power-user" \
PLUMOS_MOUNTS_FILE="$tmp/mounts" \
PLUMOS_BUSYBOX="$tmp/fake-busybox" \
PLUMOS_TEST_POWER_CALLS="$tmp/power-calls.log" \
PLUMOS_NETWORK_SERVICES=/nonexistent \
PLUMOS_POWER_REQUEST="$tmp/power-request" \
    sh "$package/bin/plumos-safe-shutdown" --reboot
if [[ ! -f "$tmp/power-root/provision/clean-shutdown" ]]; then exit 1; fi
if [[ ! -f "$tmp/power-user/.plumos-clean-shutdown" ]]; then exit 1; fi
grep -q "^umount $tmp/power-user$" "$tmp/power-calls.log"
grep -qx reboot "$tmp/power-request"
! grep -Eq '^(reboot|poweroff) ' "$tmp/power-calls.log"
# Repeating the same FE action after a committed request must let the UI exit;
# /run cannot contain a stale request from an earlier boot.
: >"$tmp/mounts"
PLUMOS_ROOT="$tmp/power-root" \
PLUMOS_RUNTIME_ROOT="$tmp/power-runtime" \
PLUMOS_USER_MOUNT="$tmp/power-user" \
PLUMOS_MOUNTS_FILE="$tmp/mounts" \
PLUMOS_BUSYBOX="$tmp/fake-busybox" \
PLUMOS_TEST_POWER_CALLS="$tmp/power-calls.log" \
PLUMOS_NETWORK_SERVICES=/nonexistent \
PLUMOS_POWER_REQUEST="$tmp/power-request" \
    sh "$package/bin/plumos-safe-shutdown" --reboot >"$tmp/power-repeat.log"
grep -q 'pending=reused' "$tmp/power-repeat.log"
if [[ ! -f "$tmp/power-root/provision/clean-shutdown" ]]; then exit 1; fi
# A user may correct an accidental Shutdown selection to Reboot while the
# original request is still awaiting PID 1.  The clean unmount remains valid.
PLUMOS_ROOT="$tmp/power-root" \
PLUMOS_RUNTIME_ROOT="$tmp/power-runtime" \
PLUMOS_USER_MOUNT="$tmp/power-user" \
PLUMOS_MOUNTS_FILE="$tmp/mounts" \
PLUMOS_BUSYBOX="$tmp/fake-busybox" \
PLUMOS_TEST_POWER_CALLS="$tmp/power-calls.log" \
PLUMOS_NETWORK_SERVICES=/nonexistent \
PLUMOS_POWER_REQUEST="$tmp/power-request" \
    sh "$package/bin/plumos-safe-shutdown" --shutdown --poweroff \
    >"$tmp/power-switch.log"
grep -q 'pending=updated-from-reboot' "$tmp/power-switch.log"
grep -qx shutdown "$tmp/power-request"
if [[ ! -f "$tmp/power-root/provision/clean-shutdown" ]]; then exit 1; fi
grep -q 'finalize_power_action' "$repo_root/rootfs/bubble-frontend/init"
grep -q 'terminate-storage /storage' "$package/bin/plumos-safe-shutdown"
grep -q 'E91_POWER_ACTION_REFUSED runtime=recoverable' \
    "$repo_root/rootfs/bubble-frontend/init"
grep -q 'E94_POWER_ACTION_REFUSED' \
    "$package/bin/plumos-power-request-finalizer"
grep -q 'ui->exit_requested = 1' "$repo_root/src/frontend/plumos_controller_ui.c"

network_script="$repo_root/package/network-services-bubble/plumos/bin/plumos-network-services"
grep -q 'if \[ "$action" = quiesce \]' "$network_script"
grep -Fq 'DROPBEAR_RUNTIME_LOG=$RUNTIME_ROOT/dropbear/dropbear.log' \
    "$network_script"
! grep -Eq 'dropbear .*>>"\$LOG"' "$network_script"
mkdir -p "$tmp/network-root/config/network"
printf 'ssh_enabled=1\nftp_enabled=1\n' >"$tmp/network-root/config/network/services.conf"
services_before=$(sha256sum "$tmp/network-root/config/network/services.conf" | awk '{print $1}')
PLUMOS_ROOT="$tmp/network-root" PLUMOS_RUNTIME_ROOT="$tmp/network-run" \
    sh "$network_script" quiesce
services_after=$(sha256sum "$tmp/network-root/config/network/services.conf" | awk '{print $1}')
if [[ $services_before != "$services_after" ]]; then exit 1; fi

network_package="$repo_root/package/network-services-bubble/plumos"
sh -n "$network_package/bin/plumos-network-services"
grep -q "name __pycache__ -empty -delete" \
    "$repo_root/scripts/build-bubble-frontend.sh"
grep -q '^install_scraper_runtime()' \
    "$repo_root/scripts/build-bubble-frontend.sh"
grep -q 'PLUMOS_SCRAPER_LIB_DIR' \
    "$repo_root/scripts/build-bubble-frontend.sh"
grep -q 'find bin config factory-defaults fonts frontend/lib scraper share themes' \
    "$repo_root/scripts/build-bubble-frontend.sh"
grep -q "print_status sftp running 'SFTP port 22'" \
    "$network_package/bin/plumos-network-services"
! grep -q 'SFTP_PORT.*2222' "$network_package/bin/plumos-network-services"
grep -q '"sftp": 22' "$repo_root/scripts/build-network-services-bubble.sh"
grep -q 'usr/lib/sftp-server' "$repo_root/scripts/build-bubble-frontend-system.sh"
grep -Fq '[IPC$]' "$network_package/bin/plumos-network-services"
grep -q 'max smbd processes = $TRANSFER_MAX_CONNECTIONS' \
    "$network_package/bin/plumos-network-services"
! grep -Rq '2222' "$package/share/frontend/lang" \
    "$package/config/frontend/start-menu-coverage.json"
PLUMOS_ROOT="$tmp/root" PLUMOS_RUNTIME_ROOT="$tmp/run" \
    sh "$network_package/bin/plumos-network-services" status adb >"$tmp/adb.log" 2>&1 || true
grep -q '^state=hardware_unavailable$' "$tmp/adb.log"

printf 'bubble_start_menu_contract=result-ok start=8 apps_visible=8 apps_hidden=3 implemented=11 bubble_only=1\n'
