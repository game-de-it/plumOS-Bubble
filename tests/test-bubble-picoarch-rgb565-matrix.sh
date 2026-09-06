#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
systems=${PLUMOS_BUBBLE_SYSTEMS_JSON:-$repo_root/package/frontend-bubble/plumos/config/frontend/systems.json}
matrix=${PLUMOS_BUBBLE_PICOARCH_RGB565_MATRIX:-$repo_root/package/picoarch-bubble/plumos/share/picoarch/rgb565-byte-order.tsv}

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
picodrive
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

printf '%s\n' 'bubble_picoarch_rgb565_matrix=result-ok routes=20 rgb565=18 byteswap=7 xrgb8888=2 compat=1'
