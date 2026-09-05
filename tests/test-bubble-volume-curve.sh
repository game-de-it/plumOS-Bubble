#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
runtime=$tmp/run
mkdir -p "$root/bin" "$root/config/system" "$runtime"
cp "$repo_root/package/frontend-bubble/plumos/bin/plumos-volume-control" \
    "$root/bin/plumos-volume-control"

cat >"$root/bin/fake-amixer" <<'EOF'
#!/bin/sh
case "$1" in
    cget) exit 0 ;;
    cset) printf '%s\n' "$3" >"${TEST_RAW:?}" ;;
    *) exit 2 ;;
esac
EOF
cat >"$root/bin/fake-audio-output" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$root/bin/fake-aplay" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$root/bin/"*
printf '{"volume": 8}\n' >"$root/config/system/settings.json"

expected='0 181 198 208 215 221 225 229 232 235 238 240 242 244 246 248 250 251 252 254 255'
level=0
for raw in $expected; do
    TEST_RAW=$tmp/raw PLUMOS_ROOT=$root PLUMOS_RUNTIME_ROOT=$runtime \
    PLUMOS_AMIXER=$root/bin/fake-amixer \
    PLUMOS_AUDIO_OUTPUT=$root/bin/fake-audio-output \
    PLUMOS_APLAY=$root/bin/fake-aplay \
        "$root/bin/plumos-volume-control" apply "$level"
    test "$(cat "$tmp/raw")" = "$raw"
    grep -q "volume=$level raw=$raw curve=pixel2-linear-amplitude-v1" \
        "$runtime/volume/last-apply.log"
    level=$((level + 1))
done
test "$level" -eq 21

printf 'bubble_volume_curve=result-ok curve=pixel2-linear-amplitude-v1 levels=21\n'
