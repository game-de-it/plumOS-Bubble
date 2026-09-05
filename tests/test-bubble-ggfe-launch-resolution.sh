#!/usr/bin/env bash
set -euo pipefail

# GGFE launch resolution.
#
# Assertions use explicit `if ... then ... fi` rather than a bare `[[ ]]`.
# macOS ships bash 3.2, which does not honour `set -e` for a failing `[[ ]]`
# compound command, so a bare assertion there is silently skipped and the test
# reports success no matter what.

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
package="$repo_root/package/frontend-bubble/plumos"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf 'test-bubble-ggfe-launch-resolution: %s\n' "$1" >&2
    exit 1
}

expect_line() {
    local pattern=$1 file=$2
    grep -Fq -- "$pattern" "$file" || {
        printf 'missing: %s\n' "$pattern" >&2
        sed -n '/^launch profiles/,$p' "$file" >&2
        fail "expectation not met"
    }
}

cc=${CC:-cc}
$cc -std=gnu99 -O1 -Wall -D_GNU_SOURCE -DPLUMOS_GGFE_HOST=1 \
    "$repo_root/src/frontend/plumos_ggfe.c" -o "$tmp/ggfe-host" -lm \
    $(pkg-config --cflags --libs libpng freetype2) 2>/dev/null ||
    fail "cannot build the GGFE host harness"

# A managed root with two of the three Game Gear cores present, so the
# unavailable ones have to be skipped rather than chosen.
root="$tmp/root"
cp -R "$package/." "$root/"
mkdir -p "$root/cores" "$root/picoarch/bin" "$root/state/frontend"
: >"$root/cores/genesis_plus_gx_libretro.so"
: >"$root/cores/gearsystem_libretro.so"
: >"$root/picoarch/bin/picoarch"

card="$tmp/card"
mkdir -p "$card/Roms/GG" "$card/Images/GG"
: >"$card/Roms/GG/Alpha (Japan).gg"
: >"$card/Roms/GG/Beta (Japan).gg"
: >"$card/Roms/GG/Gamma (Japan).gg"

cat >"$root/state/frontend/core-overrides.json" <<'JSON'
{
  "system_overrides": [
    {"system_id": "gamegear", "launch_profile": "retroarch:gearsystem"}
  ],
  "rom_overrides": [
    {"system_id": "gamegear", "relative_path": "GG/Beta (Japan).gg",
     "launch_profile": "picoarch:genesis_plus_gx"},
    {"system_id": "gamegear", "relative_path": "GG/Gamma (Japan).gg",
     "launch_profile": "retroarch:picodrive"}
  ]
}
JSON

cat >"$root/state/frontend/ggfe-overrides.json" <<'JSON'
{
  "rom_overrides": [
    {"system_id": "gamegear", "relative_path": "GG/Beta (Japan).gg",
     "launch_profile": "retroarch:genesis_plus_gx"}
  ]
}
JSON

"$tmp/ggfe-host" "$root" "$card" "$tmp" >"$tmp/out.txt" 2>&1 ||
    fail "the GGFE host harness did not run"

# Availability: an unpackaged core is reported, not silently dropped.
expect_line "retroarch:genesis_plus_gx          available" "$tmp/out.txt"
expect_line "retroarch:picodrive                core not packaged: picodrive" "$tmp/out.txt"
expect_line "picoarch:gearsystem                available" "$tmp/out.txt"

# Alpha has no override anywhere, so the plumOS system override decides.
expect_line "Alpha (Japan)                            retroarch:gearsystem           plumos system override" "$tmp/out.txt"
# Beta has both: GGFE's own override wins within the same scope.
expect_line "Beta (Japan)                             retroarch:genesis_plus_gx      ggfe rom override" "$tmp/out.txt"
# Gamma's plumOS ROM override names a core this device does not have, so the
# chain continues instead of failing.
expect_line "Gamma (Japan)                            retroarch:gearsystem           plumos system override" "$tmp/out.txt"

# GGFE must never write plumOS's override file.
before=$(cksum <"$root/state/frontend/core-overrides.json")
"$tmp/ggfe-host" "$root" "$card" "$tmp" >/dev/null 2>&1 || true
after=$(cksum <"$root/state/frontend/core-overrides.json")
if [ "$before" != "$after" ]; then
    fail "GGFE modified the plumOS core-overrides file"
fi

printf 'bubble_ggfe_launch_resolution=result-ok profiles=6 available=4 roms=3\n'
