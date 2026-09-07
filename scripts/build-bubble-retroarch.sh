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
        ./scripts/build-bubble-retroarch.sh --inside
fi

repo_root=/work
ref=${PLUMOS_BUBBLE_RETROARCH_REF:-v1.22.2}
url=https://github.com/libretro/RetroArch.git
assets_url=https://github.com/libretro/retroarch-assets.git
assets_ref=73106363e14e34c08a5854b4cfbc29f184e3b783
work=$repo_root/output/build/retroarch-bubble-$ref
assets_work=$repo_root/output/build/retroarch-assets-$assets_ref
out=$repo_root/output/retroarch/bubble
root=$out/plumos
bin=$root/bin
lib=$root/emulator/lib
component=$root/components/retroarch
source_ref=$(git -c safe.directory="$repo_root" -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
epoch=${SOURCE_DATE_EPOCH:-}
[[ -n $epoch ]] || epoch=$(git -c safe.directory="$repo_root" -C "$repo_root" show -s --format=%ct HEAD)
export SOURCE_DATE_EPOCH=$epoch

if [[ ! -d $work/.git ]]; then
    rm -rf "$work"
    git clone --filter=blob:none "$url" "$work"
fi
git -C "$work" fetch --tags --quiet origin
git -C "$work" checkout --quiet "$ref"
git -C "$work" reset --hard --quiet
git -C "$work" clean -fdx --quiet
for patch in "$repo_root"/patches/retroarch/*.patch; do git -C "$work" apply "$patch"; done
if [[ ! -d $assets_work/.git ]]; then
    rm -rf "$assets_work"
    git clone --filter=blob:none "$assets_url" "$assets_work"
fi
git -C "$assets_work" fetch --quiet origin "$assets_ref"
git -C "$assets_work" checkout --quiet --detach "$assets_ref"
git -C "$assets_work" reset --hard --quiet "$assets_ref"
git -C "$assets_work" clean -fdx --quiet
(
    cd "$work"
    ./configure --prefix=/usr \
        --disable-x11 --disable-wayland --disable-opengl --disable-opengl1 \
        --disable-opengl_core --enable-opengles --enable-egl --enable-kms \
        --enable-plain_drm --enable-rgui --enable-xmb --enable-ozone \
        --enable-freetype \
        --disable-sdl --disable-sdl2 --enable-alsa --enable-udev \
        --disable-pulse --disable-jack --disable-oss --disable-vulkan \
        --disable-ffmpeg --disable-networking
    make -j"${JOBS:-$(nproc)}"
    for feature in OPENGLES EGL KMS DRM; do
        grep -Eq "^HAVE_${feature} = 1$" config.mk || {
            printf 'error: RetroArch feature was not built: %s\n' "$feature" >&2
            exit 1
        }
    done
    for menu_driver in RGUI XMB OZONE; do
        grep -Eq "^HAVE_${menu_driver} = 1$" config.mk || {
            printf 'error: RetroArch menu driver was not built: %s\n' \
                "$menu_driver" >&2
            exit 1
        }
    done
    grep -Eq '^HAVE_LANGEXTRA = 1$' config.mk || {
        printf 'error: RetroArch multi-language support was not built\n' >&2
        exit 1
    }
    nm retroarch >menu-symbols.txt
    for menu_symbol in menu_ctx_rgui menu_ctx_ozone menu_ctx_xmb; do
        grep -Eq "[[:space:]]${menu_symbol}$" menu-symbols.txt || {
            printf 'error: RetroArch menu symbol is missing: %s\n' \
                "$menu_symbol" >&2
            exit 1
        }
    done
    rm -f menu-symbols.txt
)

rm -rf "$out"
mkdir -p "$bin" "$lib" "$component" "$root/licenses" \
    "$root/retroarch/assets" \
    "$root/factory-defaults/retroarch/autoconfig/udev" \
    "$root/factory-defaults/shaders" "$root/share/alsa"
install -m 0755 "$work/retroarch" "$bin/retroarch"
install -m 0755 /usr/bin/amixer "$bin/plumos-amixer"
strip "$bin/retroarch" "$bin/plumos-amixer"
install -m 0644 "$work/COPYING" "$root/licenses/RetroArch-COPYING"
for asset_tree in fonts glui ozone pkg rgui sounds xmb; do
    [[ -d $assets_work/$asset_tree ]] || {
        printf 'error: RetroArch assets tree is missing: %s\n' \
            "$asset_tree" >&2
        exit 1
    }
    cp -a "$assets_work/$asset_tree" "$root/retroarch/assets/"
done
install -m 0644 "$assets_work/COPYING" \
    "$root/licenses/RetroArch-Assets-COPYING"
install -m 0644 "$assets_work/README.md" \
    "$root/licenses/RetroArch-Assets-README.md"
install -m 0644 "$repo_root/configs/retroarch/bubble-software-drm.cfg" \
    "$root/factory-defaults/retroarch/retroarch-bubble.cfg"
install -m 0644 "$repo_root/configs/retroarch/bubble-pre-v90s-expanded.cfg" \
    "$root/factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg"
install -m 0644 "$repo_root/configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg" \
    "$root/factory-defaults/retroarch/autoconfig/udev/"
# Shader presets are seeded into the user-writable shader directory by the
# launcher, so a user edit survives an update.
for shader in "$repo_root"/configs/retroarch/shaders/*; do
    install -m 0644 "$shader" "$root/factory-defaults/shaders/"
done
cp -a /usr/share/alsa/. "$root/share/alsa/"
install -m 0644 "$repo_root/configs/alsa/bubble-minimal.conf" \
    "$root/share/alsa/alsa.conf"
install -m 0644 /usr/share/doc/libasound2/copyright \
    "$root/licenses/libasound2-copyright"
install -m 0644 /usr/share/doc/libasound2-data/copyright \
    "$root/licenses/libasound2-data-copyright"
install -m 0644 /usr/share/doc/alsa-utils/copyright \
    "$root/licenses/alsa-utils-copyright"
install -m 0644 /usr/share/doc/libc6/copyright \
    "$root/licenses/libc6-copyright"

stage_libraries() {
    local file path soname
    for file in "$@"; do
        while IFS= read -r path; do
            [[ -f $path ]] || continue
            soname=$(basename "$path")
            case "$soname" in
                libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|ld-linux-*.so.*|\
                libEGL.so.*|libGLESv2.so.*|libgbm.so.*|libGLdispatch.so.*|\
                libwayland-server.so.*|libffi.so.*|libexpat.so.*) continue ;;
            esac
            [[ -f $lib/$soname ]] || install -m 0644 "$path" "$lib/$soname"
        done < <(ldd "$file" | awk '/=> \// {print $3} /^[[:space:]]*\// {print $1}')
    done
}
stage_libraries "$bin/retroarch" "$bin/plumos-amixer"
# The captured RK3566 Mali userspace predates glibc 2.34 and still declares
# the former libpthread/libdl compatibility DSOs.  Bubble's minimal System
# intentionally omits those stubs even though their symbols live in libc now.
# Keep the matching Debian bookworm compatibility objects component-scoped so
# loading the vendor EGL stack does not change the global System runtime.
for compat_library in libpthread.so.0 libdl.so.2; do
    compat_path=/lib/aarch64-linux-gnu/$compat_library
    [[ -f $compat_path ]] || {
        printf 'error: glibc compatibility library is missing: %s\n' \
            "$compat_path" >&2
        exit 1
    }
    install -m 0644 "$compat_path" "$lib/$compat_library"
done
needed=$(readelf -d "$bin/retroarch" | awk '/NEEDED/ {print $5}' | tr -d '[]')
printf '%s\n' "$needed" | grep -qx 'libEGL.so.1'
printf '%s\n' "$needed" | grep -qx 'libGLESv2.so.2'
printf '%s\n' "$needed" | grep -qx 'libgbm.so.1'
resolved=$(git -C "$work" rev-parse HEAD)
resolved_assets=$(git -C "$assets_work" rev-parse HEAD)
cat >"$component/manifest.json" <<EOF
{
  "name": "RetroArch for plumOS Bubble",
  "component": "retroarch",
  "device": "bubble",
  "version": "$ref",
  "source": "$url",
  "source_commit": "$resolved",
  "source_ref": "$source_ref",
  "source_date_epoch": $epoch,
  "video_drivers": ["drm", "gl"],
  "video_context_drivers": ["kms"],
  "menu_drivers": ["rgui", "xmb", "ozone"],
  "menu_assets": "retroarch/assets",
  "menu_assets_source": "$assets_url",
  "menu_assets_commit": "$resolved_assets",
  "menu_languages": "libretro-language-catalog-with-Japanese",
  "rendering": "software-plain-drm-and-hardware-kms-egl-gles",
  "gpu_runtime_required": false,
  "hardware_core_gpu_runtime_required": true,
  "external_gpu_runtime": ["emulator/lib/libEGL.so.1", "emulator/lib/libGLESv2.so.2", "emulator/lib/libgbm.so.1", "emulator/lib/libmali.so.1", "/dev/mali0"],
  "audio_driver": "alsa",
  "input_driver": "udev",
  "factory_config_baseline": "V90S-derived-Pixel2",
  "factory_config_keys": 3376,
  "library_scope": "emulator/lib"
}
EOF
(
    cd "$root"
    find bin emulator factory-defaults licenses retroarch share/alsa -type f -print | LC_ALL=C sort |
        while IFS= read -r path; do sha256sum "$path"; done
    sha256sum components/retroarch/manifest.json
) >"$component/checksums.sha256"
(cd "$root" && sha256sum -c components/retroarch/checksums.sha256)
readelf -h "$bin/retroarch" | grep -q 'Machine:.*AArch64'
echo "bubble_retroarch=result-ok root=$root source_commit=$resolved"
