#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
systems=${PLUMOS_BUBBLE_SYSTEMS_JSON:-$repo_root/package/frontend-bubble/plumos/config/frontend/systems.json}
apps=${PLUMOS_BUBBLE_APPS_JSON:-$repo_root/package/frontend-bubble/plumos/config/frontend/apps.json}
coverage=${PLUMOS_BUBBLE_RUNTIME_COVERAGE_JSON:-$repo_root/package/frontend-bubble/plumos/config/frontend/runtime-coverage.json}
rocknix_policy=${PLUMOS_BUBBLE_ROCKNIX_EXTENSION_POLICY:-$repo_root/package/frontend-bubble/plumos/config/frontend/rocknix-extension-policy.json}
picoarch_rgb565_matrix=${PLUMOS_BUBBLE_PICOARCH_RGB565_MATRIX:-$repo_root/package/picoarch-bubble/plumos/share/picoarch/rgb565-byte-order.tsv}
picoarch_rgb565_overrides=${PLUMOS_BUBBLE_PICOARCH_RGB565_OVERRIDES:-$repo_root/package/picoarch-bubble/plumos/share/picoarch/rgb565-route-overrides.tsv}
app_root=${PLUMOS_BUBBLE_APP_ROOT:-}

for json in "$systems" "$apps" "$coverage" "$rocknix_policy"; do
    jq -e . "$json" >/dev/null
done

PLUMOS_BUBBLE_SYSTEMS_JSON=$systems \
PLUMOS_BUBBLE_PICOARCH_RGB565_MATRIX=$picoarch_rgb565_matrix \
PLUMOS_BUBBLE_PICOARCH_RGB565_OVERRIDES=$picoarch_rgb565_overrides \
    "$repo_root/tests/test-bubble-picoarch-rgb565-matrix.sh"

jq -e '.scan_excluded_directories == ["save", "saves", "state", "states", "cache"]' \
    "$systems" >/dev/null

test "$(jq '.systems | length' "$systems")" -eq 97
test "$(jq '[.systems[].launch_profiles[]] | length' "$systems")" -eq 196
test "$(jq '[.systems[].launch_profiles[] | select(startswith("retroarch:")) | sub("^retroarch:"; "")] | unique | length' "$systems")" -eq 116
test "$(jq '[.systems[].launch_profiles[] | select(startswith("picoarch:")) | sub("^picoarch:"; "")] | unique | length' "$systems")" -eq 20
test "$(jq '[.systems[].launch_profiles[] | select(startswith("standalone:")) | sub("^standalone:"; "")] | unique | length' "$systems")" -eq 5
test "$(jq '[.systems[].launch_profiles[] | select(startswith("pyxel:"))] | length' "$systems")" -eq 1
test "$(jq '[.systems[].launch_profiles[] | select(startswith("external:"))] | length' "$systems")" -eq 1

test "$(jq '[.systems[].id] | length' "$systems")" -eq \
    "$(jq '[.systems[].id] | unique | length' "$systems")"

jq -e '
  all(.systems[];
    (.id | length) > 0 and
    (.directory_aliases | length) > 0 and
    (.extensions | type) == "array" and
    (.default_launch_profile as $default |
      ((.launch_profiles | length) == 0 or
       (.launch_profiles | index($default)) != null)))
' "$systems" >/dev/null

jq -e '
  .version == 2 and
  .reference.source_commit == "552674316206d815df7e6d755a4e307db2862005" and
  .reference.canonical_sha256 == "ccc8959d791e99a3fde28586b8405b4c2252e19e5c189c004f006e9c905b9258" and
  .reference.system_count == 139 and
  ([.systems[].system_id] | length) ==
    ([.systems[].system_id] | unique | length) and
  all(.systems[];
    if .state == "mapped" then
      (.rocknix_ids | length) > 0 and
      (([.required_extensions[], .excluded_extensions[].extension] | unique | sort) ==
       (.reference_extensions | unique | sort)) and
      all(.excluded_extensions[]; (.reason | length) > 0)
    elif .state == "not_in_reference" then
      (.rocknix_ids | length) == 0 and
      (.reference_extensions | length) == 0 and
      (.required_extensions | length) == 0 and
      (.excluded_extensions | length) == 0
    else
      false
    end)
' "$rocknix_policy" >/dev/null

jq -e --slurpfile policy "$rocknix_policy" '
  .systems as $catalog |
  (($catalog | map(.id) | sort) ==
   ($policy[0].systems | map(.system_id) | sort)) and
  all($policy[0].systems[];
    . as $rule |
    ($catalog[] | select(.id == $rule.system_id) | .extensions) as $actual |
    all($rule.required_extensions[];
      . as $extension | ($actual | index($extension)) != null) and
    all($rule.excluded_extensions[];
      .extension as $extension | ($actual | index($extension)) == null))
' "$systems" >/dev/null

for route in \
    scraping file_manager music_player retroarch pyxel_setup portmaster portmaster_update; do
    jq -e --arg id "$route" '.apps[] | select(.id == $id and .visible == true)' \
        "$apps" >/dev/null
done

for alias in \
    'ATARI/2600' 'ATARI/5200' 'ATARI/7800' 'ATARI/800' \
    'ATARI/Jaguar' 'ATARI/Lynx' '_etc/3do' '_etc/EASYRPG' \
    '_etc/pc-9800' '_etc/viretualboy' 'msx2'; do
    jq -e --arg alias "$alias" \
        '.systems[].directory_aliases[] | select(.name == $alias and .source == "rom2")' \
        "$systems" >/dev/null
done

jq -e 'all(.systems[]; .id != "3ds")' "$systems" >/dev/null
jq -e '
  .systems[] |
  select(.id == "j2me" and
         .enabled == false and
         .launch_profiles == ["retroarch:squirreljme"] and
         .default_launch_profile == "retroarch:squirreljme" and
         .support.state == "unsupported" and
         .support.reason == "squirreljme-runtime-cannot-boot-supported-content-or-produce-audio" and
         .support.todo == "BUB-P6-10" and
         .scraper.reason == "unsupported_runtime")
' "$systems" >/dev/null
jq -e '
  .systems[] |
  select(.id == "vmu" and
         (.extensions | sort) == (["bin", "dci", "vms"] | sort) and
         (.extensions | index("vmi")) == null and
         .launch_profiles == ["retroarch:vemulator"])
' "$systems" >/dev/null
jq -e --slurpfile systems "$systems" '
  .version == 2 and
  .device == "bubble" and
  .release_complete == false and
  .catalog.systems == 97 and
  .catalog.launch_profile_occurrences == 196 and
  .catalog.source_libretro_cores == 114 and
  ((.systems | map(.system_id) | sort) ==
   ($systems[0].systems | map(.id) | sort)) and
  ([.systems[].routes[]] | length) == 196 and
  ([.systems[].routes[].profile] | map(select(startswith("retroarch:"))) | map(sub("^retroarch:"; "")) | unique | length) == 116 and
  ([.systems[].routes[].profile] | map(select(startswith("picoarch:"))) | map(sub("^picoarch:"; "")) | unique | length) == 20 and
  ([.systems[].routes[].profile] | map(select(startswith("standalone:"))) | map(sub("^standalone:"; "")) | unique | length) == 5 and
  all(.systems[];
    (.system_id | length) > 0 and
    (.directory_aliases | length) > 0 and
    (.extensions | type) == "array" and
    (.default_launch_profile as $default |
      ((.routes | length) == 0 or ([.routes[].profile] | index($default)) != null)) and
    all(.routes[];
      (.profile | length) > 0 and
      (.renderer | length) > 0 and
      (.binary | length) > 0 and
      (.ownership_policy as $policy | . as $route |
        ($policy | length) > 0 and
        ($route.content_extensions | type) == "array") and
      (.bios.policy | length) > 0 and
      (.bios.files | type) == "array" and
      (.license.status | length) > 0 and
      (.license.path | length) > 0 and
      (.save_supported | type) != "null" and
      (.state_supported | type) != "null"))
' "$coverage" >/dev/null

jq -e '
  .systems[] |
  select(.system_id == "ti83") |
  .routes[] |
  select(.profile == "retroarch:numero" and
         .bios.policy == "required-any" and
         ([.bios.files[].path] | sort) ==
           (["ti83.rom", "ti83plus.rom", "ti83se.rom"] | sort))
' "$coverage" >/dev/null

jq -e --slurpfile coverage "$coverage" '
  all(.systems[];
    .id as $system_id |
    (.launch_profiles | sort) ==
      ($coverage[0].systems[] | select(.system_id == $system_id) |
       [.routes[].profile] | sort) and
    (.extensions | sort) ==
      ($coverage[0].systems[] | select(.system_id == $system_id) |
       .extensions | sort))
' "$systems" >/dev/null

if [ -n "$app_root" ]; then
    generated_coverage=$(mktemp "${TMPDIR:-/tmp}/bubble-runtime-coverage.XXXXXX")
    trap 'rm -f "$generated_coverage"' EXIT HUP INT TERM
    "$repo_root/scripts/generate-bubble-runtime-coverage.py" \
        --systems "$systems" --app-root "$app_root" --output "$generated_coverage"
    cmp "$coverage" "$generated_coverage"

    jq -r '.systems[].routes[] | select(.license.status == "packaged" or .license.status == "project-approved-inclusion") | .license.path' \
        "$coverage" | sort -u | while IFS= read -r license_path; do
        test -f "$app_root/$license_path" || {
            printf 'error: missing packaged license evidence: %s\n' "$license_path" >&2
            exit 1
        }
    done
    jq -r '.systems[].routes[].binary' "$coverage" | sort -u | while IFS= read -r binary; do
        test -e "$app_root/$binary" || {
            printf 'error: coverage binary is absent: %s\n' "$binary" >&2
            exit 1
        }
    done

    test -x "$app_root/bin/retroarch"
    test -x "$app_root/bin/plumos-retroarch-launch"
    jq -r '.systems[].launch_profiles[] | select(startswith("retroarch:")) | sub("^retroarch:"; "")' \
        "$systems" | sort -u | while IFS= read -r core_id; do
        test -f "$app_root/cores/${core_id}_libretro.so" || {
            printf 'error: unresolved RetroArch core route: %s\n' "$core_id" >&2
            exit 1
        }
    done

    test -x "$app_root/bin/plumos-picoarch-launch"
    test -x "$app_root/picoarch/bin/picoarch"
    test -f "$app_root/picoarch/lib/libSDL2-2.0.so.0"
    test -f "$app_root/licenses/picoarch-SDL2-LICENSE.txt"
    cmp "$picoarch_rgb565_matrix" "$app_root/share/picoarch/rgb565-byte-order.tsv"
    cmp "$picoarch_rgb565_overrides" "$app_root/share/picoarch/rgb565-route-overrides.tsv"
    jq -r '.systems[].launch_profiles[] | select(startswith("picoarch:")) | sub("^picoarch:"; "")' \
        "$systems" | sort -u | while IFS= read -r core_id; do
        test -f "$app_root/cores/${core_id}_libretro.so" || {
            printf 'error: unresolved PicoArch core route: %s\n' "$core_id" >&2
            exit 1
        }
    done

    test -x "$app_root/bin/plumos-standalone-launch"
    while IFS=':' read -r emulator_id binary; do
        test -x "$app_root/$binary" || {
            printf 'error: unresolved standalone route: %s\n' "$emulator_id" >&2
            exit 1
        }
    done <<'EOF'
pcsx_rearmed:emulator/standalone/pcsx_rearmed/pcsx
yabasanshiro:emulator/standalone/yabasanshiro/yabasanshiro
drastic:emulator/standalone/drastic/drastic
ppsspp:emulator/standalone/ppsspp/bin/PPSSPPSDL
openbor:emulator/standalone/openbor/bin/OpenBOR
EOF

    test -x "$app_root/bin/plumos-pyxel-bubble-launch"
    test -x "$app_root/bin/plumos-portmaster-launch"
    test -x "$app_root/bin/plumos-portmaster-port-launch"
    for app_launcher in \
        plumos-nextcommander-launch plumos-music-player-launch \
        plumos-retroarch-menu-launch plumos-pyxel-setup \
        plumos-portmaster-launch plumos-portmaster-update \
        plumos-thumbnail-scraper; do
        test -x "$app_root/bin/$app_launcher" || {
            printf 'error: visible FE route has no launcher: %s\n' "$app_launcher" >&2
            exit 1
        }
    done
fi

printf '%s\n' \
    'bubble_emulator_catalog=result-ok systems=97 profiles=196 retroarch_ids=116 picoarch_ids=20 standalone_ids=5 release_complete=no'
