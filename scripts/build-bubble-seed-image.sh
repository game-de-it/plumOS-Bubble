#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}

if [ "${1:-}" != "--inside" ]; then
    "$repo_root/scripts/build-bubble-minimal-system.sh"
    exec docker run --rm --platform linux/arm64 \
        -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}" \
        -e PLUMOS_BUBBLE_VERSION="${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}" \
        -v "$repo_root:/work" -w /work "$tools_image" \
        ./scripts/build-bubble-seed-image.sh --inside
fi

repo_root=/work
stock=$repo_root/artifacts/vendor/bubble-stock-source
boot=$stock/boot
prefix=$stock/rockchip-boot-prefix.bin
system_dir=$repo_root/output/system-rootfs/bubble-minimal/payload
out_dir=$repo_root/output/image/bubble
work=$repo_root/work/bubble-seed-image
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
source_epoch=${SOURCE_DATE_EPOCH:-}
[ -n "$source_epoch" ] || source_epoch=$(git -C "$repo_root" show -s --format=%ct HEAD)
case "$source_epoch" in ''|*[!0-9]*) echo 'invalid SOURCE_DATE_EPOCH' >&2; exit 2;; esac

expected_prefix=648078e91860adf21bd4ec8f1fd8a64ce52de0ce24511393b156b920327b4ec2
test "$(stat -c '%s' "$prefix")" -eq 16777216
test "$(sha256sum "$prefix" | cut -d' ' -f1)" = "$expected_prefix"
(cd "$system_dir" && sha256sum -c checksums.sha256)

verify_registered() {
    registered_name=$1
    artifact=$2
    expected=$(awk -v name="$registered_name" '$2 == name {print $1}' \
        "$repo_root/configs/bubble-stock-active-boot.expected.sha256")
    actual=$(sha256sum "$artifact" | cut -d' ' -f1)
    test -n "$expected"
    test "$actual" = "$expected"
}
verify_registered Image "$boot/Image"
verify_registered boot.cmd "$boot/boot.cmd"
verify_registered boot.scr "$boot/boot.scr"
verify_registered uEnv.txt "$boot/uEnv.txt"
verify_registered rk3566-gkd-geek-bbg.dtb \
    "$boot/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/rk3566-gkd-geek-bbg.dtb"
verify_registered rk3566-gkd-geek-bbg-hdmi.dtb \
    "$boot/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/rk3566-gkd-geek-bbg-hdmi.dtb"
verify_registered rk3568-fiq-debugger-uart2m0.dtbo \
    "$boot/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/overlay/rk3568-fiq-debugger-uart2m0.dtbo"
verify_registered rk3568-disable-npu.dtbo \
    "$boot/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/overlay/rk3568-disable-npu.dtbo"
verify_registered rockchip-fixup.scr \
    "$boot/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/overlay/rockchip-fixup.scr"

case "$work" in /work/work/bubble-seed-image) ;; *) exit 2;; esac
find "$work" -depth -delete 2>/dev/null || true
mkdir -p "$work/boot" "$work/storage/plumos/logs" "$work/storage/update-state" "$out_dir"

kernel_version=4.19.193-51-rockchip-gb2c01b3d79f2
dtb_root=$work/boot/dtbs/$kernel_version/rockchip
mkdir -p "$dtb_root/overlay" "$work/boot/plumos-probe/original"
install -m 0644 "$boot/Image" "$work/boot/Image"
install -m 0644 "$boot/dtbs/$kernel_version/rockchip/rk3566-gkd-geek-bbg.dtb" "$dtb_root/"
install -m 0644 "$boot/dtbs/$kernel_version/rockchip/rk3566-gkd-geek-bbg-hdmi.dtb" "$dtb_root/"
for file in rk3568-fiq-debugger-uart2m0.dtbo rk3568-disable-npu.dtbo rockchip-fixup.scr; do
    install -m 0644 "$boot/dtbs/$kernel_version/rockchip/overlay/$file" "$dtb_root/overlay/"
done
install -m 0644 "$system_dir/SYSTEM" "$work/boot/SYSTEM"
install -m 0644 "$system_dir/SYSTEM.manifest" "$work/boot/SYSTEM.manifest"
install -m 0644 "$boot/boot.cmd" "$work/boot/plumos-probe/original/boot.cmd"
install -m 0644 "$boot/boot.scr" "$work/boot/plumos-probe/original/boot.scr"
python3 "$repo_root/scripts/instrument-bubble-boot-script.py" "$boot/boot.cmd" "$work/instrumented"
install -m 0644 "$work/instrumented/boot.cmd" "$work/boot/boot.cmd"
install -m 0644 "$work/instrumented/boot.scr" "$work/boot/boot.scr"
sed \
    -e 's/^rootuuid=.*/rootuuid=42554242-4c45-5359-5300-000000000002/' \
    -e '$a extraboardargs=plumos_seed=1' \
    "$boot/uEnv.txt" > "$work/boot/uEnv.txt"
printf '%s\n' '----' > "$work/boot/plumos-probe/uboot-stage.txt"
printf '%s\n' 'NOT_REACHED' > "$work/boot/plumos-probe/system-stage.txt"
printf '%s\n' 'PLUMOS_BUBBLE_SEED_V1' > "$work/boot/plumos-probe/seed-authorized.txt"

cat > "$work/storage/plumos/seed.manifest" <<EOF
format=plumos-bubble-seed-v1
device=bubble
version=$version
source_ref=$source_ref
source_date_epoch=$source_epoch
boot_substrate=stock-bubble
kernel_release=4.19.193-g5a07852a55cf-dirty
system=minimal-diagnostic-userland
storage_policy=diagnostic-ext4-remounted-read-only-after-log
EOF

cat > "$work/boot/plumos-image.manifest" <<EOF
format=plumos-bubble-seed-v1
device=bubble
architecture=aarch64
version=$version
source_ref=$source_ref
source_date_epoch=$source_epoch
boot_prefix_sha256=$expected_prefix
boot_substrate=stock-bubble
kernel_release=4.19.193-g5a07852a55cf-dirty
stock_image_sha256=$(sha256sum "$boot/Image" | cut -d' ' -f1)
stock_dtb_sha256=$(sha256sum "$boot/dtbs/$kernel_version/rockchip/rk3566-gkd-geek-bbg.dtb" | cut -d' ' -f1)
system_sha256=$(sha256sum "$system_dir/SYSTEM" | cut -d' ' -f1)
layout=bringup-v1,raw-prefix-16MiB,p1-fat32-512MiB,p2-ext4-remainder
root_uuid=42554242-4c45-5359-5300-000000000002
logging=uboot-fat,system-console,system-kmsg,system-fat,system-ext4
EOF

total_sectors=4194304
boot_start=32768
boot_sectors=1048576
sys_start=1081344
sys_sectors=3112960
image_path=$out_dir/plumOS-Bubble-$version-seed.img
boot_fat=$work/boot.fat
sys_ext4=$work/storage.ext4
truncate -s "$((total_sectors * 512))" "$image_path"
dd if="$prefix" of="$image_path" bs=1M count=16 conv=notrunc status=none
parted -s "$image_path" unit s mklabel msdos \
    mkpart primary fat32 "${boot_start}s" "$((boot_start + boot_sectors - 1))s" \
    mkpart primary ext4 "${sys_start}s" "$((sys_start + sys_sectors - 1))s" \
    set 1 boot on 2> "$work/parted.stderr"
grep -v 'udevadm: not found' "$work/parted.stderr" >&2 || true
printf '\102\125\102\114' | dd of="$image_path" bs=1 seek=440 conv=notrunc status=none

truncate -s "$((boot_sectors * 512))" "$boot_fat"
truncate -s "$((sys_sectors * 512))" "$sys_ext4"
SOURCE_DATE_EPOCH="$source_epoch" mkfs.vfat --invariant -F 32 -n PLUMBOOT \
    -i 42554242 "$boot_fat" >/dev/null
find "$work/boot" "$work/storage" -exec touch -h -d "@$source_epoch" {} +
E2FSPROGS_FAKE_TIME="$source_epoch" mkfs.ext4 -q -F -L PLUMOS_SYS \
    -U 42554242-4c45-5359-5300-000000000002 \
    -E lazy_itable_init=0,lazy_journal_init=0,hash_seed=42554242-4c45-5359-5300-000000000002 \
    -d "$work/storage" "$sys_ext4"
# mke2fs -d preserves the host ctime for imported inodes.  ctime cannot be
# backdated with touch(1), so normalize the populated paths explicitly.
# Root and lost+found are already governed by E2FSPROGS_FAKE_TIME.
for ext4_path in /plumos /plumos/logs /plumos/seed.manifest /update-state; do
    debugfs -w -R "set_inode_field $ext4_path ctime @$source_epoch" \
        "$sys_ext4" >/dev/null 2>&1
done
MTOOLS_SKIP_CHECK=1 mcopy -m -o -s -i "$boot_fat" "$work/boot/"* ::/

dd if="$boot_fat" of="$image_path" bs=512 seek="$boot_start" conv=notrunc status=none
dd if="$sys_ext4" of="$image_path" bs=512 seek="$sys_start" conv=notrunc status=none
cmp -i 512:512 -n 16776704 "$prefix" "$image_path"
fsck.fat -vn "$boot_fat" >/dev/null
e2fsck -fn "$sys_ext4" >/dev/null

image_size=$(stat -c '%s' "$image_path")
image_sha=$(sha256sum "$image_path" | cut -d' ' -f1)
cat > "$out_dir/image.manifest" <<EOF
format=plumos-bubble-seed-v1
file=$(basename "$image_path")
image_size=$image_size
image_sha256=$image_sha
source_ref=$source_ref
source_date_epoch=$source_epoch
boot_prefix_sha256=$expected_prefix
boot_filesystem_sha256=$(sha256sum "$boot_fat" | cut -d' ' -f1)
sys_filesystem_sha256=$(sha256sum "$sys_ext4" | cut -d' ' -f1)
EOF
(cd "$out_dir" && sha256sum "$(basename "$image_path")" image.manifest > checksums.sha256)
echo "bubble_seed_image=result-ok image=$image_path sha256=$image_sha"
