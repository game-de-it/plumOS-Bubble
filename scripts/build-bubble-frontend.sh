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
scraper_lib=$root/scraper/lib
storage_tools=$root/storage-tools
storage_tools_lib=$storage_tools/lib
storage_tools_gconv=$storage_tools/gconv
component=$root/components/frontend
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -c safe.directory="$repo_root" -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
epoch=${SOURCE_DATE_EPOCH:-}
[[ -n $epoch ]] || epoch=$(git -c safe.directory="$repo_root" -C "$repo_root" show -s --format=%ct HEAD)
export SOURCE_DATE_EPOCH=$epoch

rm -rf "$out"
mkdir -p "$out"
cp -a "$repo_root/package/frontend-bubble/plumos/." "$root/"
# Host-side Python validation may leave ignored bytecode beside the managed
# update helper.  It is neither runtime input nor reproducible release data.
find "$root" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
find "$root" -depth -type d -name __pycache__ -empty -delete
mkdir -p "$bin" "$lib" "$scraper_lib" "$storage_tools_lib" \
    "$storage_tools_gconv" "$component" "$root/state/frontend" \
    "$root/config/frontend" "$root/config/system" "$root/logs"

common=(-std=gnu99 -Os -pipe -Wall -Wextra -D_GNU_SOURCE)
png_cflags=$(pkg-config --cflags libpng)
png_libs=$(pkg-config --libs libpng)
jpeg_cflags=$(pkg-config --cflags libjpeg)
jpeg_libs=$(pkg-config --libs libjpeg)
webp_cflags=$(pkg-config --cflags libwebp)
webp_libs=$(pkg-config --libs libwebp)
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
# GGFE: the Game Gear frontend.  Same CPU renderer path as the stock frontend,
# no GL and no /dev/mali0, so it never competes for the GPU or for DRM master.
# shellcheck disable=SC2086
gcc "${common[@]}" $png_cflags $jpeg_cflags $webp_cflags $ft_cflags $drm_cflags \
    -DPLUMOS_ENABLE_FBDEV_RENDERER=1 -DPLUMOS_FBDEV_ENABLE_PNG=1 \
    -DPLUMOS_FBDEV_ENABLE_FREETYPE=1 -DPLUMOS_FBDEV_ENABLE_DRM=1 \
    -DGGFE_PROFILE=1 \
    src/frontend/plumos_ggfe.c -o "$bin/plumos-ggfe" \
    $png_libs $jpeg_libs $webp_libs $ft_libs $drm_libs -lm -lpthread
gcc "${common[@]}" src/services/plumos_bubble_volume_keys.c \
    -o "$bin/plumos-volume-keys"
gcc "${common[@]}" $drm_cflags src/services/plumos_drm_master.c \
    -o "$bin/plumos-drm-master"
gcc "${common[@]}" $drm_cflags src/services/plumos_drm_broker_run.c \
    -o "$bin/plumos-drm-broker-run"
gcc "${common[@]}" -fPIC -shared src/services/plumos_drm_share.c \
    -o "$lib/libplumos-drm-share.so" -ldl
for name in plumos_library_scan plumos_text_ui plumos_frontend; do
    gcc "${common[@]}" "src/frontend/${name}.c" -o "$bin/${name//_/-}"
done
install -m 0755 /usr/bin/amixer "$bin/plumos-amixer"
install -m 0755 /usr/bin/aplay "$bin/plumos-aplay"
install -m 0755 /usr/bin/openssl "$bin/plumos-openssl.bin"
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
stage_libraries "$bin/plumos-controller-ui-fbdev" "$bin/plumos-ggfe" \
    "$bin/plumos-library-scan" \
    "$bin/plumos-text-ui" "$bin/plumos-frontend" "$bin/plumos-amixer" \
    "$bin/plumos-aplay" "$bin/plumos-openssl.bin"

# The stock Bubble BusyBox wget crashes during HTTPS transfers.  Keep the
# scraper independent from the stock rootfs, as MF and Pixel2 do, by packaging
# curl with its complete recursive runtime closure and CA bundle.
scraper_runtime_libs=""

scraper_runtime_needed() {
    readelf -d "$1" 2>/dev/null |
        awk '/NEEDED/ { gsub(/[][]/, "", $5); print $5 }'
}

find_scraper_runtime_library() {
    local soname="$1" candidate
    for candidate in \
        "/lib/aarch64-linux-gnu/$soname" \
        "/usr/lib/aarch64-linux-gnu/$soname" \
        "/lib/$soname" "/usr/lib/$soname"; do
        if [[ -e $candidate ]]; then
            readlink -f "$candidate"
            return 0
        fi
    done
    return 1
}

copy_scraper_runtime_library() {
    local soname="$1" source child
    case " $scraper_runtime_libs " in *" $soname "*) return 0 ;; esac
    source=$(find_scraper_runtime_library "$soname") || {
        printf 'error: scraper runtime library not found: %s\n' "$soname" >&2
        exit 1
    }
    install -m 0755 "$source" "$scraper_lib/$soname"
    scraper_runtime_libs="$scraper_runtime_libs $soname"
    while IFS= read -r child; do
        [[ -n $child ]] || continue
        copy_scraper_runtime_library "$child"
    done < <(scraper_runtime_needed "$source")
}

install_scraper_runtime() {
    local curl_bin=/usr/bin/curl loader soname
    local doc_dir=$root/share/doc/frontend

    [[ -x $curl_bin ]] || {
        printf 'error: toolchain curl is unavailable: %s\n' "$curl_bin" >&2
        exit 1
    }
    install -m 0755 "$curl_bin" "$scraper_lib/plumos-curl"
    while IFS= read -r soname; do
        [[ -n $soname ]] || continue
        copy_scraper_runtime_library "$soname"
    done < <(scraper_runtime_needed "$curl_bin")

    loader=$(readlink -f /lib/ld-linux-aarch64.so.1 2>/dev/null || true)
    [[ -n $loader && -f $loader ]] || \
        loader=$(readlink -f /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1)
    install -m 0755 "$loader" "$scraper_lib/ld-linux-aarch64.so.1"
    install -m 0644 /etc/ssl/certs/ca-certificates.crt \
        "$scraper_lib/ca-certificates.crt"

    mkdir -p "$doc_dir"
    install -m 0644 /usr/share/doc/curl/copyright "$doc_dir/curl-copyright"
    [[ ! -r /usr/share/doc/libcurl4/copyright ]] || \
        install -m 0644 /usr/share/doc/libcurl4/copyright \
            "$doc_dir/libcurl-copyright"
    [[ ! -r /usr/share/doc/ca-certificates/copyright ]] || \
        install -m 0644 /usr/share/doc/ca-certificates/copyright \
            "$doc_dir/ca-certificates-copyright"
    install -m 0644 /usr/share/doc/libjpeg62-turbo/copyright \
        "$doc_dir/libjpeg62-turbo-copyright"
    install -m 0644 /usr/share/doc/libwebp7/copyright \
        "$doc_dir/libwebp7-copyright"

    cat >"$bin/curl" <<'EOF'
#!/bin/sh
set -eu
PLUMOS_ROOT="${PLUMOS_ROOT:-/storage/plumos}"
PLUMOS_SCRAPER_LIB_DIR="${PLUMOS_SCRAPER_LIB_DIR:-$PLUMOS_ROOT/scraper/lib}"
export CURL_CA_BUNDLE="${CURL_CA_BUNDLE:-$PLUMOS_SCRAPER_LIB_DIR/ca-certificates.crt}"
export SSL_CERT_FILE="${SSL_CERT_FILE:-$CURL_CA_BUNDLE}"
exec "$PLUMOS_SCRAPER_LIB_DIR/ld-linux-aarch64.so.1" \
    --library-path "$PLUMOS_SCRAPER_LIB_DIR" \
    "$PLUMOS_SCRAPER_LIB_DIR/plumos-curl" "$@"
EOF
    chmod 0755 "$bin/curl"
}

install_scraper_runtime

# SD2 repair is an explicit Apps action, never a boot-time operation. Package
# dosfstools with its own runtime so it does not depend on the vendor ABI.
install -m 0755 /usr/sbin/fsck.fat "$storage_tools/fsck.fat"
install -m 0755 /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 \
    "$storage_tools_lib/ld-linux-aarch64.so.1"
install -m 0755 /lib/aarch64-linux-gnu/libc.so.6 "$storage_tools_lib/libc.so.6"
install -m 0644 /usr/lib/aarch64-linux-gnu/gconv/GBK.so \
    "$storage_tools_gconv/GBK.so"
install -m 0644 /usr/lib/aarch64-linux-gnu/gconv/gconv-modules.d/gconv-modules-extra.conf \
    "$storage_tools_gconv/gconv-modules"
mkdir -p "$root/share/doc/storage-tools"
install -m 0644 /usr/share/doc/dosfstools/copyright \
    "$root/share/doc/storage-tools/dosfstools-copyright"
install -m 0644 /usr/share/doc/libc6/copyright \
    "$root/share/doc/storage-tools/glibc-copyright"

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
  "volume_keys": {
    "daemon": "bin/plumos-volume-keys",
    "service": "bin/plumos-volume-keys-service",
    "input_name": "gpio-keys",
    "codes": [114, 115],
    "policy": "single-persistent-owner"
  },
  "power_menu": {
    "input_name": "rk805 pwrkey",
    "code": 116,
    "frontend_policy": "delegate-when-frontend-owns-display",
    "foreground_policy": "quiesce-display-owner-and-handoff-drm",
    "overlay": "bin/plumos-power-menu-overlay",
    "runtime_quiesce": "bin/plumos-runtime-quiesce",
    "request_finalizer": "bin/plumos-power-request-finalizer",
    "request_finalizer_policy": "pid1-preferred-8s-recovery-fallback",
    "drm_handoff": "scm-rights-broker",
    "drm_broker": "bin/plumos-drm-broker-run",
    "drm_share": "frontend/lib/libplumos-drm-share.so",
    "drm_control": "bin/plumos-drm-master"
  },
  "gamegear_lcd_shader_policy": {
    "launcher": "bin/plumos-retroarch-launch",
    "launch_scope": "system-gamegear-only",
    "default_preset": "full",
    "diagnostic_presets": ["panel-only", "off"],
    "video_driver": "gl",
    "video_context_driver": "kms",
    "persistent_retroarch_config_modified": false
  },
  "library_scope": "frontend/lib",
  "scraper_http_client": "bin/curl",
  "scraper_runtime": "scraper/lib",
  "cpu_backend": "bin/plumos-cpu-control",
  "start_menu_contract": "config/frontend/start-menu-coverage.json",
  "storage_repair": {
    "app": "bin/plumos-sd2-repair",
    "checker": "storage-tools/fsck.fat",
    "policy": "explicit-confirmation-unmount-repair-remount",
    "codepage_policy": "inherit-active-sd2-mount"
  },
  "ggfe": {
    "binary": "bin/plumos-ggfe",
    "config": "config/frontend/ggfe.json",
    "assets": "themes/default/ggfe",
    "renderer": "cpu-software-3d",
    "gpu_requirement": "none"
  },
  "start_menu_entries": 8,
  "apps_menu_entries": 12,
  "bubble_only_menu_entries": ["sd2_repair", "ggfe"],
  "settings_backends": ["display", "volume", "network", "network-services", "time-sync", "factory-reset", "storage-health", "cpu", "safe-power", "signed-runtime-update"],
  "cpu_policies": ["interactive", "performance", "ondemand", "schedutil", "conservative"],
  "reference_port": "plumOS-MF@0095017c39226ad1c22bf8df852202673075936d"
}
EOF
printf '%s\n' "$version" >"$root/VERSION"
(
    cd "$root"
    find bin config factory-defaults fonts frontend/lib scraper storage-tools share themes -type f \
        ! -path 'bin/plumos-network-services' -print | LC_ALL=C sort |
        while IFS= read -r path; do sha256sum "$path"; done
    sha256sum components/frontend/manifest.json VERSION
) >"$component/checksums.sha256"
(cd "$root" && sha256sum -c components/frontend/checksums.sha256)
readelf -h "$bin/plumos-controller-ui-fbdev" | grep -q 'Machine:.*AArch64'
readelf -h "$bin/plumos-ggfe" | grep -q 'Machine:.*AArch64'
# GGFE must not pull in a GL stack: that is the whole point of the CPU path.
if ldd "$bin/plumos-ggfe" | grep -Eq 'libEGL|libGLESv2|libgbm|libmali'; then
    echo "plumos-ggfe linked a GL stack" >&2
    exit 1
fi
gcc -std=gnu99 -Os -Wall -Wextra \
    "$repo_root/scripts/probe-font-glyphs.c" \
    -o /tmp/probe-font-glyphs $(pkg-config --cflags --libs freetype2)
/tmp/probe-font-glyphs "$root/fonts/default.otf" 304c 30a2 65e5 9b42
/tmp/probe-font-glyphs "$root/fonts/cjk-fallback.ttc" 304c 30a2 65e5 9b42
echo "bubble_frontend=result-ok root=$root"
