#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
systems=${PLUMOS_BUBBLE_SYSTEMS_JSON:-$repo_root/package/frontend-bubble/plumos/config/frontend/systems.json}
matrix=${PLUMOS_BUBBLE_PICOARCH_RGB565_MATRIX:-$repo_root/package/picoarch-bubble/plumos/share/picoarch/rgb565-byte-order.tsv}
overrides=${PLUMOS_BUBBLE_PICOARCH_RGB565_OVERRIDES:-$repo_root/package/picoarch-bubble/plumos/share/picoarch/rgb565-route-overrides.tsv}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

jq -r '.systems[].launch_profiles[] | select(startswith("picoarch:")) | sub("^picoarch:"; "")' \
    "$systems" | sort -u >"$tmp/routes"
awk -F '\t' '
    /^#/ { next }
    NF != 5 { exit 1 }
    $1 !~ /^[A-Za-z0-9._-]+$/ { exit 1 }
    $2 != "rgb565" && $2 != "xrgb8888" { exit 1 }
    $3 != "native" && $3 != "byteswap" { exit 1 }
    $2 == "xrgb8888" && $3 != "native" { exit 1 }
    $4 != "frontend" && $4 != "compat" { exit 1 }
    $5 == "" { exit 1 }
    seen[$1]++ { exit 1 }
    $4 == "frontend" { print $1 > routes }
    $3 == "byteswap" && $4 == "frontend" { print $1 > swaps }
    $2 == "xrgb8888" && $4 == "frontend" { print $1 > xrgb }
    END { if (length(seen) != 21) exit 1 }
' routes="$tmp/matrix-routes" swaps="$tmp/matrix-swaps" xrgb="$tmp/matrix-xrgb" "$matrix"
sort -o "$tmp/matrix-routes" "$tmp/matrix-routes"
sort -o "$tmp/matrix-swaps" "$tmp/matrix-swaps"
sort -o "$tmp/matrix-xrgb" "$tmp/matrix-xrgb"

cmp "$tmp/routes" "$tmp/matrix-routes"
cat >"$tmp/expected-swaps" <<'EOF'
gambatte
gearboy
gearsystem
mednafen_supafaust
mednafen_supergrafx
vbam
EOF
cmp "$tmp/expected-swaps" "$tmp/matrix-swaps"
cat >"$tmp/expected-xrgb" <<'EOF'
fceumm
nestopia
EOF
cmp "$tmp/expected-xrgb" "$tmp/matrix-xrgb"

test "$(wc -l < "$tmp/routes")" -eq 20
test "$(awk -F '\t' '$4 == "frontend" && $2 == "rgb565" { n++ } END { print n + 0 }' "$matrix")" -eq 18
test "$(awk -F '\t' '$1 == "mednafen_ngp" && $4 == "compat" && $3 == "byteswap" { n++ } END { print n + 0 }' "$matrix")" -eq 1

jq -r '.systems[] as $system | $system.launch_profiles[] |
  select(. == "picoarch:picodrive") | [$system.id, "picodrive"] | @tsv' \
  "$systems" | sort -u >"$tmp/picodrive-routes"
awk -F '\t' '
    /^#/ { next }
    NF != 6 { exit 1 }
    $1 !~ /^[A-Za-z0-9._-]+$/ || $2 != "picodrive" { exit 1 }
    $3 != "rgb565" { exit 1 }
    $4 != "native" && $4 != "byteswap" { exit 1 }
    $5 != "frontend" || $6 == "" { exit 1 }
    seen[$1 FS $2]++ { exit 1 }
    { print $1 FS $2 > routes }
    END { if (length(seen) != 4) exit 1 }
' routes="$tmp/override-routes" "$overrides"
sort -o "$tmp/override-routes" "$tmp/override-routes"
comm -23 "$tmp/override-routes" "$tmp/picodrive-routes" >"$tmp/unexposed-overrides"
test ! -s "$tmp/unexposed-overrides"
cat >"$tmp/expected-overrides" <<'EOF'
gamegear	picodrive	rgb565	byteswap	frontend	device-pengo-180f
mastersystem	picodrive	rgb565	native	frontend	device-wonder-boy-iii-180f
megadrive	picodrive	rgb565	native	frontend	device-bare-knuckle-180f
sega32x	picodrive	rgb565	native	frontend	device-bc-racers-180f
EOF
grep -v '^#' "$overrides" | sort >"$tmp/actual-overrides"
cmp "$tmp/expected-overrides" "$tmp/actual-overrides"

printf '%s\n' 'bubble_picoarch_rgb565_matrix=result-ok routes=20 rgb565=18 core_byteswap=6 route_overrides=4 xrgb8888=2 compat=1'
