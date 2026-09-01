#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/output/build/drastic-bubble"
SOURCE_DIR="$BUILD_ROOT/source"
RELEASE_DIR="$BUILD_ROOT/release"
OVERLAY_DIR="$BUILD_ROOT/overlay"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_DRASTIC_OUT:-output/drastic/bubble}"
DOWNLOAD_DIR="$ROOT_DIR/output/downloads"
ARCHIVE="${PLUMOS_BUBBLE_DRASTIC_ARCHIVE:-$DOWNLOAD_DIR/drastic_miyoo-flip_20251104.zip}"
PREBUILT_LIB_ROOT="${PLUMOS_BUBBLE_DRASTIC_SOURCE_LIB_ROOT:-}"
PREBUILT_RUNTIME_ROOT="${PLUMOS_BUBBLE_DRASTIC_RUNTIME_ROOT:-}"
PREBUILT_COMPAT="${PLUMOS_BUBBLE_DRASTIC_COMPAT_LIBRARY:-}"
SOURCE_URL="https://github.com/steward-fu/nds.git"
SOURCE_REF="b88e6b75963106c0bd54dfe112f860c6bdbfe593"
SOURCE_TAG="final-china-devices"
RELEASE_URL="https://github.com/steward-fu/nds/releases/download/final-china-devices/drastic_miyoo-flip_20251104.zip"
RELEASE_SHA256="9e4ed98047dea0f014daea7c3530793f92f19d60073fceb9fd2a040696f66491"
COMMON_SHA256="2ea331892fc5f7b35a9db707593d7767270d1fd2bce1ac00187850ac41b440b2"
DETOUR_SHA256="fd4a2cf5c4e0d8650a82f7ca3af8836ec793916b67f8305b9773780e1ca3c3c1"
SDL2_SHA256="e85539cdf71606ee7aa8bbdfb5a744ca52ab49790ab1011c45688b23a48333e3"
PATCH="$ROOT_DIR/package/standalone-bubble/patches/drastic/steward-fu-nds-bubble-toolchain.patch"
COMPAT_SOURCE="$ROOT_DIR/package/standalone-bubble/src/drastic-mmap-compat.c"
JOBS="${JOBS:-4}"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'error: required command is missing: %s\n' "$1" >&2
        exit 1
    }
}

verify_sha256() {
    local expected="$1"
    local path="$2"
    local actual

    actual="$(sha256sum "$path" | awk '{ print $1 }')"
    [ "$actual" = "$expected" ] || {
        printf 'error: unexpected SHA-256 for %s\nexpected: %s\nactual:   %s\n' \
            "$path" "$expected" "$actual" >&2
        exit 1
    }
}

copy_overlay_file() {
    local name="$1"
    local destination="$2"
    local source

    source="$(find "$OVERLAY_DIR" -type f -name "$name" -print | head -n 1)"
    [ -n "$source" ] || {
        printf 'error: private runtime file is missing: %s\n' "$name" >&2
        exit 1
    }
    install -m 0755 "$source" "$destination"
}

for command in curl git make patch rsync sha256sum unzip; do
    require_command "$command"
done
if [ -z "$PREBUILT_LIB_ROOT" ] || [ -z "$PREBUILT_COMPAT" ]; then
    require_command arm-linux-gnueabihf-gcc
fi

mkdir -p "$DOWNLOAD_DIR"
if [ ! -f "$ARCHIVE" ]; then
    curl -L --fail --retry 3 --output "$ARCHIVE" "$RELEASE_URL"
fi
verify_sha256 "$RELEASE_SHA256" "$ARCHIVE"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
unzip -q "$ARCHIVE" -d "$RELEASE_DIR"
[ -x "$RELEASE_DIR/drastic/drastic" ] || {
    printf 'error: release archive does not contain the ARM32 DraStic core\n' >&2
    exit 1
}

if [ -z "$PREBUILT_LIB_ROOT" ]; then
    rm -rf "$SOURCE_DIR"
    git clone --filter=blob:none --no-checkout --depth 1 \
        --branch "$SOURCE_TAG" "$SOURCE_URL" "$SOURCE_DIR"
    git -C "$SOURCE_DIR" sparse-checkout init --no-cone
    git -C "$SOURCE_DIR" sparse-checkout set \
        Makefile.base \
        Makefile.miyoo_flip \
        LICENSE \
        assets/miyoo_flip \
        common \
        detour \
        drastic \
        inc \
        sdl2
    git -C "$SOURCE_DIR" checkout "$SOURCE_REF"
    git -C "$SOURCE_DIR" apply "$PATCH"
    make -C "$SOURCE_DIR" -f Makefile.miyoo_flip -j"$JOBS" \
        TOOLCHAIN_BIN="$(dirname "$(command -v arm-linux-gnueabihf-gcc)")" \
        NDS_INCLUDE_ROOT=/usr/include
    SOURCE_LIB_ROOT="$SOURCE_DIR/drastic/lib"
else
    SOURCE_LIB_ROOT="$PREBUILT_LIB_ROOT"
fi

verify_sha256 "$COMMON_SHA256" "$SOURCE_LIB_ROOT/libcommon.so"
verify_sha256 "$DETOUR_SHA256" "$SOURCE_LIB_ROOT/libdtr.so"
verify_sha256 "$SDL2_SHA256" "$SOURCE_LIB_ROOT/libSDL2-2.0.so.0"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT/lib" "$OUT_ROOT/runtime/lib32"
rsync -a \
    --exclude='._*' \
    --exclude='drastic64' \
    --exclude='launch.sh' \
    --exclude='overlayfs.img' \
    --exclude='lib/libcommon.so' \
    --exclude='lib/libdtr.so' \
    --exclude='lib/libSDL2-2.0.so.0' \
    "$RELEASE_DIR/drastic/" "$OUT_ROOT/"
# The Miyoo Flip release maps the in-game menu to an analog direction. Bubble's
# normalized controller exposes FUNCTION as SDL button 8, encoded by DraStic
# as 1024 + 8. Keep this as the packaged factory value.
sed \
    's/^controls_b\[CONTROL_INDEX_MENU\] = 1154$/controls_b[CONTROL_INDEX_MENU] = 1034/' \
    "$OUT_ROOT/config/drastic.cfg" >"$OUT_ROOT/config/drastic.cfg.next"
mv "$OUT_ROOT/config/drastic.cfg.next" "$OUT_ROOT/config/drastic.cfg"
grep -Fqx 'controls_b[CONTROL_INDEX_MENU] = 1034' \
    "$OUT_ROOT/config/drastic.cfg" || {
    printf 'error: DraStic FUNCTION menu factory mapping was not applied\n' >&2
    exit 1
}
install -m 0644 "$SOURCE_LIB_ROOT/libcommon.so" "$OUT_ROOT/lib/libcommon.so"
install -m 0644 "$SOURCE_LIB_ROOT/libdtr.so" "$OUT_ROOT/lib/libdtr.so"
install -m 0644 "$SOURCE_LIB_ROOT/libSDL2-2.0.so.0" \
    "$OUT_ROOT/lib/libSDL2-2.0.so.0"

if [ -n "$PREBUILT_RUNTIME_ROOT" ]; then
    rsync -a "$PREBUILT_RUNTIME_ROOT/" "$OUT_ROOT/runtime/"
else
    require_command debugfs
    rm -rf "$OVERLAY_DIR"
    mkdir -p "$OVERLAY_DIR"
    debugfs -R "rdump / $OVERLAY_DIR" \
        "$RELEASE_DIR/drastic/overlayfs.img" >/dev/null
    copy_overlay_file ld-linux-armhf.so.3 \
        "$OUT_ROOT/runtime/ld-linux-armhf.so.3"
    for library in \
        libEGL.so.1 \
        libGLESv2.so.2 \
        libasound.so.2 \
        libc.so.6 \
        libdl.so.2 \
        libdrm.so.2 \
        libfreetype.so.6 \
        libgbm.so.1 \
        libgcc_s.so.1 \
        libm.so.6 \
        libmali.so.1 \
        libmali_hook.so.1 \
        libpthread.so.0 \
        librt.so.1 \
        libstdc++.so.6; do
        copy_overlay_file "$library" "$OUT_ROOT/runtime/lib32/$library"
    done
fi

if [ -n "$PREBUILT_COMPAT" ]; then
    install -m 0644 "$PREBUILT_COMPAT" \
        "$OUT_ROOT/lib/libdrastic_mmap_compat.so"
else
    arm-linux-gnueabihf-gcc -Os -fPIC -shared \
        -Wl,-soname,libdrastic_mmap_compat.so \
        -o "$OUT_ROOT/lib/libdrastic_mmap_compat.so" "$COMPAT_SOURCE"
fi
install -m 0644 "$RELEASE_DIR/drastic/readme.txt" \
    "$OUT_ROOT/upstream-release-readme.txt"
if [ -f "$SOURCE_DIR/LICENSE" ]; then
    install -m 0644 "$SOURCE_DIR/LICENSE" "$OUT_ROOT/integration-LICENSE"
else
    curl -L --fail --retry 3 \
        --output "$OUT_ROOT/integration-LICENSE" \
        "https://raw.githubusercontent.com/steward-fu/nds/$SOURCE_REF/LICENSE"
fi

compat_sha256="$(sha256sum "$OUT_ROOT/lib/libdrastic_mmap_compat.so" |
    awk '{ print $1 }')"
core_sha256="$(sha256sum "$OUT_ROOT/drastic" | awk '{ print $1 }')"
if [ -n "$PREBUILT_LIB_ROOT" ]; then
    integration_origin=verified-prebuilt-input
else
    integration_origin=source-built
fi
cat >"$OUT_ROOT/build-manifest.json" <<EOF
{
  "device": "bubble",
  "upstream": "steward-fu/nds",
  "source_ref": "$SOURCE_REF",
  "release_asset": "drastic_miyoo-flip_20251104.zip",
  "release_sha256": "$RELEASE_SHA256",
  "closed_core": {
    "path": "drastic",
    "sha256": "$core_sha256",
    "built_from_source": false
  },
  "source_built_integration": {
    "origin": "$integration_origin",
    "libcommon.so": "$COMMON_SHA256",
    "libdtr.so": "$DETOUR_SHA256",
    "libSDL2-2.0.so.0": "$SDL2_SHA256",
    "libdrastic_mmap_compat.so": "$compat_sha256"
  },
  "runtime_contract": "package-local-armhf-glibc-mali",
  "global_usr_overlay": false,
  "process_aslr": "disabled-only-for-drastic"
}
EOF

(
    cd "$OUT_ROOT"
    find . -type f ! -path './checksums.sha256' -print |
        sed 's#^\./##' |
        sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$OUT_ROOT/checksums.sha256"
(
    cd "$OUT_ROOT"
    sha256sum -c checksums.sha256
)
printf 'created: %s\n' "$OUT_ROOT"
