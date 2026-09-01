#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [[ ${1:-} != --inside ]]; then
    if [[ ${1:-} != --assemble-only ]]; then
        "$repo_root/scripts/build-bubble-frontend.sh"
        "$repo_root/scripts/build-bubble-retroarch.sh"
        "$repo_root/scripts/build-libretro-core-catalog-bubble.sh" \
            --filter all --concurrency "${PLUMOS_BUBBLE_CORE_CONCURRENCY:-2}"
        "$repo_root/scripts/build-picoarch-bubble.sh"
        "$repo_root/scripts/build-standalone-bubble.sh"
        "$repo_root/scripts/build-pyxel-bubble.sh"
        "$repo_root/scripts/build-portmaster-bubble.sh"
    fi
    for required in \
        output/libretro-cores/bubble-all/plumos \
        output/picoarch/bubble/plumos \
        output/standalone/bubble/plumos \
        output/pyxel/bubble/plumos \
        output/portmaster/bubble/plumos; do
        [[ -d "$repo_root/$required" ]] || {
            printf 'error: full emulator-stack input is missing: %s\n' "$required" >&2
            exit 1
        }
    done
    exec docker run --rm --platform linux/arm64 \
        -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}" \
        -e PLUMOS_BUBBLE_VERSION="${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}" \
        -v "$repo_root:/work" -w /work "$image" \
        ./scripts/build-bubble-app-layer.sh --inside
fi

repo_root=/work
out=$repo_root/output/app-layer/bubble
root=$out/plumos
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -c safe.directory="$repo_root" -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
epoch=${SOURCE_DATE_EPOCH:-}
[[ -n $epoch ]] || epoch=$(git -c safe.directory="$repo_root" -C "$repo_root" show -s --format=%ct HEAD)

rm -rf "$out"
mkdir -p "$root"
cp -a "$repo_root/output/frontend/bubble/plumos/." "$root/"
cp -a "$repo_root/output/retroarch/bubble/plumos/." "$root/"
cp -a "$repo_root/output/libretro-cores/bubble-all/plumos/." "$root/"
cp -a "$repo_root/output/picoarch/bubble/plumos/." "$root/"
cp -a "$repo_root/output/standalone/bubble/plumos/." "$root/"
cp -a "$repo_root/output/pyxel/bubble/plumos/." "$root/"
cp -a "$repo_root/output/portmaster/bubble/plumos/." "$root/"
mkdir -p "$root/config/frontend" "$root/config/system" "$root/config/retroarch" \
    "$root/state/frontend" "$root/logs" "$root/saves" "$root/states"

for json in "$root"/config/frontend/*.json "$root"/factory-defaults/*/*.json \
    "$root"/components/*/manifest.json; do jq -e . "$json" >/dev/null; done
PLUMOS_BUBBLE_APP_ROOT="$root" \
    "$repo_root/scripts/verify-bubble-emulator-catalog.sh"
for component in \
    frontend retroarch libretro-cores picoarch standalone pyxel portmaster; do
    (cd "$root" && sha256sum -c "components/$component/checksums.sha256")
done
LD_LIBRARY_PATH="$root/emulator/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    python3 "$repo_root/scripts/smoke-load-libretro-cores-bubble.py" \
    --root "$root" >"$out/libretro-core-load-smoke.log"
grep -Fqx 'bubble_libretro_load_smoke=result-ok pass=114 fail=0' \
    "$out/libretro-core-load-smoke.log"

cat >"$root/manifest.json" <<EOF
{
  "name": "plumOS Bubble bring-up app layer",
  "device": "bubble",
  "version": "$version",
  "source_ref": "$source_ref",
  "source_date_epoch": $epoch,
  "managed_components": ["frontend", "retroarch", "libretro-cores", "picoarch", "standalone", "pyxel", "portmaster"],
  "frontend": "cpu-drm-dumb-buffer",
  "retroarch": "software-plain-drm-rgui",
  "core_baseline": "all-114-source-records",
  "catalog_complete": true,
  "release_complete": false,
  "catalog_systems": 98,
  "catalog_launch_profile_occurrences": 196,
  "coverage_manifest": "config/frontend/runtime-coverage.json",
  "mutable_paths": ["config/frontend/settings.json", "config/system/settings.json", "config/retroarch", "logs", "state", "saves", "states"],
  "user_media_included": false,
  "managed_firmware_assets": ["blueMSX C-BIOS", "DraStic packaged BIOS (non-release-eligible)"],
  "publishable": false,
  "non_publishable_reasons": ["physical route matrix pending", "captured vendor Mali license pending", "DraStic Bubble input bridge missing", "3DS has no runtime"]
}
EOF
(
    cd "$root"
    find . -type f ! -path './checksums.sha256' \
        ! -path './config/frontend/settings.json' \
        ! -path './config/system/settings.json' \
        ! -path './config/retroarch/*' \
        ! -path './logs/*' ! -path './state/*' ! -path './saves/*' ! -path './states/*' \
        -print | sed 's#^./##' | LC_ALL=C sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$root/checksums.sha256"
(cd "$root" && sha256sum -c checksums.sha256)

PLUMOS_ROOT="$root" PLUMOS_SDCARD_ROOT="$out" \
    "$root/bin/plumos-library-scan" --defer-thumbnails >"$out/library-scan.log" 2>&1
PLUMOS_ROOT="$root" PLUMOS_SDCARD_ROOT="$out" PLUMOS_RENDERER=text \
    "$root/bin/plumos-controller-ui-fbdev" --renderer text \
    --script start,b,q --no-clear >"$out/frontend-script.log" 2>&1
grep -q 'START' "$out/frontend-script.log"
! find "$out" -type f \( -iname '*.nes' -o -iname '*.unf' -o -iname '*.unif' \) -print -quit | grep -q .
echo "bubble_app_layer=result-ok root=$root"
