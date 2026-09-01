#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [[ ${1:-} != --inside ]]; then
    docker image inspect "$image" >/dev/null 2>&1 || "$repo_root/scripts/build-bubble-tools-image.sh"
    exec docker run --rm --platform linux/arm64 \
        -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}" \
        -v "$repo_root:/work" -w /work "$image" \
        ./scripts/build-bubble-quicknes.sh --inside
fi

repo_root=/work
url=https://github.com/libretro/QuickNES_Core.git
ref=058d66516ed3f1260b69e5b71cd454eb7e9234a3
work=$repo_root/output/build/quicknes-bubble
out=$repo_root/output/libretro-cores/bubble
root=$out/plumos
component=$root/components/libretro-cores
source_ref=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
epoch=${SOURCE_DATE_EPOCH:-}
[[ -n $epoch ]] || epoch=$(git -C "$repo_root" show -s --format=%ct HEAD)
export SOURCE_DATE_EPOCH=$epoch
if [[ ! -d $work/.git ]]; then rm -rf "$work"; git clone --filter=blob:none "$url" "$work"; fi
git -C "$work" fetch --quiet origin "$ref"
git -C "$work" checkout --quiet --detach "$ref"
git -C "$work" reset --hard --quiet "$ref"
git -C "$work" clean -fdx --quiet
make -C "$work" -j"${JOBS:-$(nproc)}" platform=unix GIT_VERSION=-${ref:0:7}
rm -rf "$out"
mkdir -p "$root/cores" "$root/info" "$root/licenses" "$component"
install -m 0644 "$work/quicknes_libretro.so" "$root/cores/quicknes_libretro.so"
strip "$root/cores/quicknes_libretro.so"
license=$(find "$work" -maxdepth 3 -type f \( -iname COPYING -o -iname LICENSE -o -iname 'LICENSE.*' \) | LC_ALL=C sort | head -1)
[[ -n $license ]]
install -m 0644 "$license" "$root/licenses/quicknes-LICENSE"
cat >"$root/info/quicknes_libretro.info" <<'EOF'
display_name = "Nintendo - NES / Famicom (QuickNES)"
authors = "blargg|libretro"
supported_extensions = "nes|unif|unf"
corename = "QuickNES"
categories = "Emulator"
license = "LGPLv2.1"
permissions = ""
display_version = "pinned"
supports_no_game = "false"
firmware_count = 0
EOF
cat >"$component/manifest.json" <<EOF
{
  "name": "QuickNES for plumOS Bubble",
  "component": "libretro-cores",
  "device": "bubble",
  "source": "$url",
  "source_commit": "$ref",
  "source_ref": "$source_ref",
  "source_date_epoch": $epoch,
  "cores": [{"id": "quicknes", "binary": "quicknes_libretro.so", "rendering": "software"}]
}
EOF
(
    cd "$root"
    sha256sum cores/quicknes_libretro.so info/quicknes_libretro.info \
        licenses/quicknes-LICENSE components/libretro-cores/manifest.json
) >"$component/checksums.sha256"
(cd "$root" && sha256sum -c components/libretro-cores/checksums.sha256)
readelf -h "$root/cores/quicknes_libretro.so" | grep -q 'Machine:.*AArch64'
echo "bubble_quicknes=result-ok root=$root source_commit=$ref"
