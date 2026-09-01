#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DISK="${1:-}"
OUT="${2:-$ROOT_DIR/artifacts/vendor/bubble-stock-source/rockchip-boot-prefix.bin}"
EXPECTED_SIZE=124383133696
EXPECTED_P1_OFFSET=16777216

case "$DISK" in
    /dev/disk[0-9]*) ;;
    *)
        printf 'usage: %s /dev/diskN [output.bin]\n' "$0" >&2
        exit 2
        ;;
esac

[ ! -e "$OUT" ] || {
    printf 'error: refusing to overwrite existing file: %s\n' "$OUT" >&2
    exit 1
}

INFO="$(diskutil info "$DISK")"
printf '%s\n' "$INFO" | grep -q 'Whole:.*Yes' || {
    printf 'error: target is not a whole disk: %s\n' "$DISK" >&2
    exit 1
}
printf '%s\n' "$INFO" | grep -q 'Removable Media:.*Removable' || {
    printf 'error: target is not removable media: %s\n' "$DISK" >&2
    exit 1
}
printf '%s\n' "$INFO" | grep -q 'Protocol:.*Secure Digital' || {
    printf 'error: target is not Secure Digital media: %s\n' "$DISK" >&2
    exit 1
}
printf '%s\n' "$INFO" | grep -q "Disk Size:.*($EXPECTED_SIZE Bytes)" || {
    printf 'error: target size does not match the observed Bubble OS SD\n' >&2
    exit 1
}

PARTITION_INFO="$(diskutil info "${DISK}s1")"
printf '%s\n' "$PARTITION_INFO" | grep -q 'Volume Name:.*EMUELEC' || {
    printf 'error: p1 is not the observed EMUELEC volume\n' >&2
    exit 1
}
printf '%s\n' "$PARTITION_INFO" | grep -q "Partition Offset:.*$EXPECTED_P1_OFFSET Bytes" || {
    printf 'error: p1 does not start at the observed 16 MiB boundary\n' >&2
    exit 1
}

diskutil unmountDisk "$DISK" >/dev/null
mkdir -p "$(dirname -- "$OUT")"
TMP_OUT="$(mktemp "${OUT}.tmp.XXXXXX")"
trap 'unlink "$TMP_OUT" 2>/dev/null || true' EXIT
RAW_DISK="/dev/r${DISK#/dev/}"

printf 'Reading the first 16 MiB from %s; no SD-card write is performed.\n' "$RAW_DISK"
sudo dd if="$RAW_DISK" of="$TMP_OUT" bs=1048576 count=16
sudo chown "$(id -u):$(id -g)" "$TMP_OUT"
[ "$(stat -f '%z' "$TMP_OUT")" -eq 16777216 ]
mv "$TMP_OUT" "$OUT"
shasum -a 256 "$OUT"
printf 'created: %s\n' "$OUT"

