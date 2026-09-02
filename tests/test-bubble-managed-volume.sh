#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
audio=$repo_root/package/frontend-bubble/plumos/bin/plumos-audio-output
volume=$repo_root/package/frontend-bubble/plumos/bin/plumos-volume-control

sh -n "$audio" "$volume"
grep -q '^pcm\.plumos_softvol {' "$audio"
grep -q '^pcm\.plumos_output {' "$audio"
grep -q '^pcm\.plumos_pyxel {' "$audio"
grep -q 'name "Soft Volume Master"' "$audio"
grep -q 'min_dB -90.0' "$audio"
grep -q 'plumos-aplay' "$volume"
grep -q 'value \* 255' "$volume"

for launcher in \
    "$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-launch" \
    "$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-menu-launch" \
    "$repo_root/package/picoarch-bubble/plumos/bin/plumos-picoarch-launch" \
    "$repo_root/package/standalone-bubble/plumos/bin/plumos-standalone-launch"; do
    grep -q 'plumos-audio-output' "$launcher"
    grep -q 'plumos-volume-control' "$launcher"
done

printf 'bubble_managed_volume=result-ok range=0..20 backend=alsa-softvol\n'
