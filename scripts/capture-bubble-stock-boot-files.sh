#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE_ROOT="${PLUMOS_BUBBLE_STOCK_BOOT_ROOT:-/Volumes/EMUELEC}"
OUT_DIR="${PLUMOS_BUBBLE_VENDOR_OUT:-$ROOT_DIR/artifacts/vendor/bubble-stock-source/boot}"
EXPECTED="$ROOT_DIR/configs/bubble-stock-active-boot.expected.sha256"
KVER=4.19.193-51-rockchip-gb2c01b3d79f2

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

expected_hash() {
    awk -v name="$1" '$2 == name { print $1; exit }' "$EXPECTED"
}

capture() {
    src="$1"
    expected_name="$2"
    rel="$3"
    expected="$(expected_hash "$expected_name")"
    [ -n "$expected" ] || {
        printf 'error: expected hash is missing for %s\n' "$expected_name" >&2
        exit 1
    }
    [ -f "$src" ] || {
        printf 'error: source artifact is missing: %s\n' "$src" >&2
        exit 1
    }
    actual="$(sha256_file "$src")"
    [ "$actual" = "$expected" ] || {
        printf 'error: hash mismatch for %s\nexpected=%s\nactual=%s\n' \
            "$expected_name" "$expected" "$actual" >&2
        exit 1
    }
    mkdir -p "$OUT_DIR/$(dirname -- "$rel")"
    [ ! -e "$OUT_DIR/$rel" ] || {
        printf 'error: refusing to overwrite captured artifact: %s\n' "$OUT_DIR/$rel" >&2
        exit 1
    }
    cp -p "$src" "$OUT_DIR/$rel"
}

mount | grep -F " on $SOURCE_ROOT " | grep -q 'read-only' || {
    printf 'error: source must be mounted read-only: %s\n' "$SOURCE_ROOT" >&2
    exit 1
}

capture "$SOURCE_ROOT/Image" Image Image
capture "$SOURCE_ROOT/boot.cmd" boot.cmd boot.cmd
capture "$SOURCE_ROOT/boot.scr" boot.scr boot.scr
capture "$SOURCE_ROOT/uEnv.txt" uEnv.txt uEnv.txt
capture "$SOURCE_ROOT/.backup/rk3566-gkd-geek-bbg-uboot.dtb" \
    rk3566-gkd-geek-bbg-uboot.dtb .backup/rk3566-gkd-geek-bbg-uboot.dtb
capture "$SOURCE_ROOT/dtbs/$KVER/rockchip/rk3566-gkd-geek-bbg.dtb" \
    rk3566-gkd-geek-bbg.dtb "dtbs/$KVER/rockchip/rk3566-gkd-geek-bbg.dtb"
capture "$SOURCE_ROOT/dtbs/$KVER/rockchip/rk3566-gkd-geek-bbg-hdmi.dtb" \
    rk3566-gkd-geek-bbg-hdmi.dtb "dtbs/$KVER/rockchip/rk3566-gkd-geek-bbg-hdmi.dtb"
capture "$SOURCE_ROOT/dtbs/$KVER/rockchip/overlay/rk3568-fiq-debugger-uart2m0.dtbo" \
    rk3568-fiq-debugger-uart2m0.dtbo "dtbs/$KVER/rockchip/overlay/rk3568-fiq-debugger-uart2m0.dtbo"
capture "$SOURCE_ROOT/dtbs/$KVER/rockchip/overlay/rk3568-disable-npu.dtbo" \
    rk3568-disable-npu.dtbo "dtbs/$KVER/rockchip/overlay/rk3568-disable-npu.dtbo"
capture "$SOURCE_ROOT/dtbs/$KVER/rockchip/overlay/rockchip-fixup.scr" \
    rockchip-fixup.scr "dtbs/$KVER/rockchip/overlay/rockchip-fixup.scr"

MANIFEST="$OUT_DIR/manifest.tsv"
{
    printf 'format\tplumos-bubble-stock-boot-v1\n'
    printf 'device\tgkd-bubble\n'
    printf 'architecture\taarch64\n'
    printf 'kernel_version\t4.19.193-g5a07852a55cf-dirty\n'
    printf 'stock_system_policy\tanalysis-only-not-copied\n'
    printf 'stock_system_sha256\t%s\n' "$(expected_hash SYSTEM.analysis-only)"
    find "$OUT_DIR" -type f ! -name manifest.tsv -print | LC_ALL=C sort | \
        while IFS= read -r path; do
            rel="${path#"$OUT_DIR/"}"
            size="$(stat -f '%z' "$path" 2>/dev/null || stat -c '%s' "$path")"
            printf 'file\t%s\t%s\t%s\n' "$rel" "$size" "$(sha256_file "$path")"
        done
} >"$MANIFEST"

[ ! -e "$OUT_DIR/SYSTEM" ] || {
    printf 'error: stock SYSTEM must not be copied into vendor output\n' >&2
    exit 1
}

printf 'created: %s\n' "$OUT_DIR"
printf 'manifest: %s\n' "$MANIFEST"

