#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cc -std=gnu99 -O2 -Wall -Wextra -D_GNU_SOURCE \
  "$repo_root/src/frontend/plumos_library_scan.c" -o "$tmp/plumos-library-scan"

mkdir -p "$tmp/sd/Roms/megadrive/EDMD/SAVE" \
  "$tmp/sd/Roms/megadrive/Collection" "$tmp/plumos/state/frontend"
: >"$tmp/sd/Roms/megadrive/Playable.bin"
: >"$tmp/sd/Roms/megadrive/Collection/Another.BIN"
: >"$tmp/sd/Roms/megadrive/EDMD/SAVE/slot-01.BIN"

cat >"$tmp/systems.json" <<'EOF'
{
  "version": 1,
  "scan_excluded_directories": ["save", "saves", "state", "states", "cache"],
  "systems": [
    {
      "id": "megadrive",
      "display_name": "Mega Drive",
      "short_name": "MD",
      "enabled": true,
      "directory_aliases": [{"name": "megadrive", "source": "test", "priority": 1}],
      "extensions": ["bin"],
      "launch_profiles": ["retroarch:picodrive"],
      "default_launch_profile": "retroarch:picodrive"
    }
  ]
}
EOF

PLUMOS_SDCARD_ROOT="$tmp/sd" PLUMOS_ROOT="$tmp/plumos" \
  "$tmp/plumos-library-scan" --systems "$tmp/systems.json" \
  --output "$tmp/library.json" --defer-thumbnails >"$tmp/scan.log"

test "$(jq '.systems[0].rom_count' "$tmp/library.json")" -eq 2
test "$(jq '.summary.directories_excluded' "$tmp/library.json")" -eq 1
jq -e '[.systems[0].roms[].relative_path] ==
  ["megadrive/Collection/Another.BIN", "megadrive/Playable.bin"]' \
  "$tmp/library.json" >/dev/null
! grep -Fq 'slot-01.BIN' "$tmp/library.json"
grep -Fq 'scan_excluded_directories: 5' "$tmp/scan.log"

printf '%s\n' 'bubble_library_scan_exclusions=result-ok valid_bin=2 excluded_save_dirs=1'
