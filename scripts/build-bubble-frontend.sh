#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [[ ${1:-} != --inside ]]; then
    docker image inspect "$image" >/dev/null 2>&1 || "$repo_root/scripts/build-bubble-tools-image.sh"
    exec docker run --rm --platform linux/arm64 \
        -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}" \
        -e PLUMOS_BUBBLE_VERSION="${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}" \
        -v "$repo_root:/work" -w /work "$image" \
        ./scripts/build-bubble-frontend.sh --inside
fi

repo_root=/work
out=$repo_root/output/frontend/bubble
root=$out/plumos
bin=$root/bin
lib=$root/frontend/lib
component=$root/components/frontend
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -c safe.directory="$repo_root" -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
epoch=${SOURCE_DATE_EPOCH:-}
[[ -n $epoch ]] || epoch=$(git -c safe.directory="$repo_root" -C "$repo_root" show -s --format=%ct HEAD)
export SOURCE_DATE_EPOCH=$epoch

rm -rf "$out"
mkdir -p "$out"
cp -a "$repo_root/package/frontend-bubble/plumos/." "$root/"
mkdir -p "$bin" "$lib" "$component" "$root/state/frontend" \
    "$root/config/frontend" "$root/config/system" "$root/logs"

common=(-std=gnu99 -Os -pipe -Wall -Wextra -D_GNU_SOURCE)
png_cflags=$(pkg-config --cflags libpng)
png_libs=$(pkg-config --libs libpng)
ft_cflags=$(pkg-config --cflags freetype2)
ft_libs=$(pkg-config --libs freetype2)
drm_cflags=$(pkg-config --cflags libdrm)
drm_libs=$(pkg-config --libs libdrm)
# shellcheck disable=SC2086
gcc "${common[@]}" $png_cflags $ft_cflags $drm_cflags \
    -DPLUMOS_ENABLE_FBDEV_RENDERER=1 -DPLUMOS_FBDEV_ENABLE_PNG=1 \
    -DPLUMOS_FBDEV_ENABLE_FREETYPE=1 -DPLUMOS_FBDEV_ENABLE_DRM=1 \
    -DPLUMOS_BUBBLE_INPUT=1 src/frontend/plumos_controller_ui.c \
    -o "$bin/plumos-controller-ui-fbdev" $png_libs $ft_libs $drm_libs
for name in plumos_library_scan plumos_text_ui plumos_frontend; do
    gcc "${common[@]}" "src/frontend/${name}.c" -o "$bin/${name//_/-}"
done
install -m 0755 /usr/bin/amixer "$bin/plumos-amixer"
install -m 0755 /usr/bin/aplay "$bin/plumos-aplay"
strip "$bin"/plumos-* 2>/dev/null || true
chmod 0755 "$bin"/plumos-*

stage_libraries() {
    local file path soname
    for file in "$@"; do
        while IFS= read -r path; do
            [[ -f $path ]] || continue
            soname=$(basename "$path")
            case "$soname" in
                libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|ld-linux-*.so.*) continue ;;
            esac
            [[ -f $lib/$soname ]] || install -m 0644 "$path" "$lib/$soname"
        done < <(ldd "$file" | awk '/=> \// {print $3} /^[[:space:]]*\// {print $1}')
    done
}
stage_libraries "$bin/plumos-controller-ui-fbdev" "$bin/plumos-library-scan" \
    "$bin/plumos-text-ui" "$bin/plumos-frontend" "$bin/plumos-amixer" \
    "$bin/plumos-aplay"

cat >"$component/manifest.json" <<EOF
{
  "name": "plumOS Bubble frontend",
  "component": "frontend",
  "device": "bubble",
  "version": "$version",
  "source_ref": "$source_ref",
  "source_date_epoch": $epoch,
  "renderer": "cpu-drm-dumb-buffer",
  "display": "runtime-discovered-640x480-dsi",
  "input": "retrogame_joypad",
  "input_mapping": "bubble-physical-labels",
  "library_scope": "frontend/lib",
  "cpu_backend": "bin/plumos-cpu-control",
  "cpu_policies": ["interactive", "performance", "ondemand", "schedutil", "conservative"],
  "reference_port": "plumOS-MF@0095017c39226ad1c22bf8df852202673075936d"
}
EOF
printf '%s\n' "$version" >"$root/VERSION"
(
    cd "$root"
    find bin config factory-defaults fonts frontend/lib share themes -type f -print | LC_ALL=C sort |
        while IFS= read -r path; do sha256sum "$path"; done
    sha256sum components/frontend/manifest.json VERSION
) >"$component/checksums.sha256"
(cd "$root" && sha256sum -c components/frontend/checksums.sha256)
readelf -h "$bin/plumos-controller-ui-fbdev" | grep -q 'Machine:.*AArch64'
gcc -std=gnu99 -Os -Wall -Wextra \
    "$repo_root/scripts/probe-font-glyphs.c" \
    -o /tmp/probe-font-glyphs $(pkg-config --cflags --libs freetype2)
/tmp/probe-font-glyphs "$root/fonts/default.otf" 304c 30a2 65e5 9b42
/tmp/probe-font-glyphs "$root/fonts/cjk-fallback.ttc" 304c 30a2 65e5 9b42
echo "bubble_frontend=result-ok root=$root"
