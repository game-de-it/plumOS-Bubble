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
    "$repo_root/src/frontend/plumos_ggfe.c" -o "$tmp/ggfe-host" -lm -lpthread \
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

# The serial fallback must neither use the uninitialised pool mutex nor retain
# its stripe counter between frames.  It must render exactly the same pixels as
# the four-thread path for every representative browse/launch frame.
for threads in 1 4; do
    $cc -std=gnu99 -O1 -Wall -D_GNU_SOURCE -DPLUMOS_GGFE_HOST=1 \
        -DGGFE_FORCE_THREADS="$threads" \
        "$repo_root/src/frontend/plumos_ggfe.c" \
        -o "$tmp/ggfe-host-$threads" -lm -lpthread \
        $(pkg-config --cflags --libs libpng freetype2) 2>/dev/null ||
        fail "cannot build the GGFE $threads-thread host harness"
    mkdir -p "$tmp/render-$threads"
    "$tmp/ggfe-host-$threads" "$root" "$card" "$tmp/render-$threads" \
        >/dev/null 2>&1 || fail "GGFE $threads-thread render failed"
done
for shot in g-library g-browse g-wrap-left g-wrap-right g-open g-hop g-insert g-seated g-no-case-launch; do
    cmp "$tmp/render-1/$shot.png" "$tmp/render-4/$shot.png" ||
        fail "one-thread and four-thread output differ: $shot"
done

expect_line "navigation=left_wrap:2 right_wrap:0 after_settle:1 up5:1 down5:2 twenty:19/0/15/5" "$tmp/out.txt"
expect_line "repeat=delay:350 interval:95 before:0 first:1 gap:0 second:1 released:0 delta:1" "$tmp/out.txt"

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

# The case toggle is remembered across runs, in GGFE's own state file.
rm -f "$root/state/frontend/ggfe-state.json"
"$tmp/ggfe-host" "$root" "$card" "$tmp" >"$tmp/state0.txt" 2>&1 || true
expect_line "show_cases=1" "$tmp/state0.txt"
GGFE_SET_CASES=0 "$tmp/ggfe-host" "$root" "$card" "$tmp" >/dev/null 2>&1 || true
if [ ! -f "$root/state/frontend/ggfe-state.json" ]; then
    fail "the case toggle was not persisted"
fi
"$tmp/ggfe-host" "$root" "$card" "$tmp" >"$tmp/state1.txt" 2>&1 || true
expect_line "show_cases=0" "$tmp/state1.txt"
GGFE_SET_CASES=1 "$tmp/ggfe-host" "$root" "$card" "$tmp" >/dev/null 2>&1 || true
"$tmp/ggfe-host" "$root" "$card" "$tmp" >"$tmp/state2.txt" 2>&1 || true
expect_line "show_cases=1" "$tmp/state2.txt"

# Both carousel motions are selectable and behave differently: snap overshoots
# past the target and settles, gallery is symmetric and never passes it.
motion_curve() {
    python3 - "$1" "$2" "$root/config/frontend/ggfe.json" <<'PY'
import collections, json, sys
path = sys.argv[3]
d = json.load(open(path), object_pairs_hook=collections.OrderedDict)
d.setdefault("motion", collections.OrderedDict())
d["motion"]["model"] = sys.argv[1]
d["motion"]["scroll_ms"] = int(sys.argv[2])
open(path, "w").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
PY
    "$tmp/ggfe-host" "$root" "$card" "$tmp" 2>/dev/null | grep '^motion_curve=' |
        sed 's/^motion_curve=//'
}

snap_curve=$(motion_curve snap 240)
gallery_curve=$(motion_curve gallery 360)
if [ "$snap_curve" = "$gallery_curve" ]; then
    fail "the motion model is not being honoured"
fi
# snap must pass 1.0 somewhere in the middle; gallery must never exceed it
python3 - "$snap_curve" "$gallery_curve" <<'PY' || exit 1
import sys
snap = [float(v) for v in sys.argv[1].split(",")]
gallery = [float(v) for v in sys.argv[2].split(",")]
if max(snap) <= 1.0:
    print("snap did not overshoot:", snap, file=sys.stderr)
    raise SystemExit(1)
if max(gallery) > 1.0001:
    print("gallery overshot:", gallery, file=sys.stderr)
    raise SystemExit(1)
if snap[3] <= gallery[3]:
    print("snap is not the faster start", file=sys.stderr)
    raise SystemExit(1)
PY

# The menu's core cycle walks the profiles this device actually has and comes
# back round to no override, writing GGFE's own file each time.
rm -f "$root/state/frontend/ggfe-overrides.json"
cycle_at() {
    GGFE_CYCLE_CORE=$1 "$tmp/ggfe-host" "$root" "$card" "$tmp" 2>/dev/null |
        grep '^core_override=' | sed 's/^core_override=//'
    rm -f "$root/state/frontend/ggfe-overrides.json"
}
[ "$(cycle_at 0)" = "(auto)" ] || fail "a fresh cartridge should have no override"
first=$(cycle_at 1)
case "$first" in
    retroarch:*|picoarch:*) ;;
    *) fail "the first cycle step did not choose a profile: $first" ;;
esac
[ "$(cycle_at 5)" = "(auto)" ] ||
    fail "the cycle did not return to no override after every available core"
# Left walks the same ring backwards, so one step back from no override lands
# on the last core rather than the first.
last=$(cycle_at 4)
back_one=$(cycle_at -1)
[ "$back_one" = "$last" ] ||
    fail "stepping back from no override gave '$back_one', expected '$last'"
[ "$(cycle_at -5)" = "(auto)" ] ||
    fail "the backward cycle did not return to no override"

# The motion choice survives a restart.
rm -f "$root/state/frontend/ggfe-state.json"
GGFE_SET_MOTION=gallery "$tmp/ggfe-host" "$root" "$card" "$tmp" >/dev/null 2>&1
"$tmp/ggfe-host" "$root" "$card" "$tmp" >"$tmp/motion1.txt" 2>&1 || true
expect_line "state_motion=gallery" "$tmp/motion1.txt"
GGFE_SET_MOTION=snap "$tmp/ggfe-host" "$root" "$card" "$tmp" >/dev/null 2>&1
"$tmp/ggfe-host" "$root" "$card" "$tmp" >"$tmp/motion2.txt" 2>&1 || true
expect_line "state_motion=snap" "$tmp/motion2.txt"

# GGFE must never write plumOS's override file.
before=$(cksum <"$root/state/frontend/core-overrides.json")
"$tmp/ggfe-host" "$root" "$card" "$tmp" >/dev/null 2>&1 || true
after=$(cksum <"$root/state/frontend/core-overrides.json")
if [ "$before" != "$after" ]; then
    fail "GGFE modified the plumOS core-overrides file"
fi

printf 'bubble_ggfe_launch_resolution=result-ok profiles=6 available=4 roms=3 case_state=persisted motion=snap,gallery core_cycle=both-directions navigation=wrap,page5 repeat=350/95 threads=1,4 identical=9\n'
