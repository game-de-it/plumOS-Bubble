#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}

if [ "${1:-}" != "--inside" ]; then
    image=${1:-$repo_root/output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img}
    case "$image" in "$repo_root"/*) ;; *) echo 'image must be under repository' >&2; exit 2;; esac
    relative=${image#"$repo_root"/}
    exec docker run --rm --platform linux/arm64 \
        -e PLUMOS_BUBBLE_VERIFY_IMAGE="/work/$relative" \
        -v "$repo_root:/work" -w /work "$tools_image" \
        ./scripts/verify-bubble-seed-image.sh --inside
fi

repo_root=/work
image=${PLUMOS_BUBBLE_VERIFY_IMAGE:?}
prefix=$repo_root/artifacts/vendor/bubble-stock-source/rockchip-boot-prefix.bin
system=$repo_root/output/system-rootfs/bubble-minimal/payload/SYSTEM
manifest=$repo_root/output/image/bubble/image.manifest
verify=$repo_root/work/bubble-seed-verify
find "$verify" -depth -delete 2>/dev/null || true
mkdir -p "$verify"

expected_size=$(awk -F= '$1 == "image_size" {print $2}' "$manifest")
expected_sha=$(awk -F= '$1 == "image_sha256" {print $2}' "$manifest")
test "$(stat -c '%s' "$image")" = "$expected_size"
test "$(sha256sum "$image" | cut -d' ' -f1)" = "$expected_sha"
test "$expected_size" -eq 2147483648

parted -ms "$image" unit s print > "$verify/partitions.txt"
grep -q '^1:32768s:1081343s:1048576s:fat32::boot, lba;$' "$verify/partitions.txt"
grep -q '^2:1081344s:4194303s:3112960s:ext4::;$' "$verify/partitions.txt"
cmp -i 512:512 -n 16776704 "$prefix" "$image"

dd if="$image" of="$verify/boot.fat" bs=512 skip=32768 count=1048576 status=none
dd if="$image" of="$verify/storage.ext4" bs=512 skip=1081344 count=3112960 status=none
fsck.fat -vn "$verify/boot.fat" >/dev/null
e2fsck -fn "$verify/storage.ext4" >/dev/null
MTOOLS_SKIP_CHECK=1 mcopy -i "$verify/boot.fat" ::/SYSTEM "$verify/SYSTEM"
cmp "$system" "$verify/SYSTEM"
MTOOLS_SKIP_CHECK=1 mtype -i "$verify/boot.fat" ::/uEnv.txt > "$verify/uEnv.txt"
grep -q '^rootuuid=42554242-4c45-5359-5300-000000000002$' "$verify/uEnv.txt"
grep -q '^extraboardargs=plumos_seed=1$' "$verify/uEnv.txt"
MTOOLS_SKIP_CHECK=1 mtype -i "$verify/boot.fat" \
    ::/plumos-probe/seed-authorized.txt | grep -q '^PLUMOS_BUBBLE_SEED_V1'
debugfs -R 'cat /plumos/seed.manifest' "$verify/storage.ext4" 2>/dev/null \
    > "$verify/seed.manifest"
grep -q '^format=plumos-bubble-seed-v1$' "$verify/seed.manifest"

echo "bubble_seed_verify=result-ok image=$image sha256=$expected_sha"
