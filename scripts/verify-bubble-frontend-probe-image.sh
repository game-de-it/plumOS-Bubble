#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}

if [ "${1:-}" != "--inside" ]; then
    image=${1:-$repo_root/output/image/bubble-frontend-probe/plumOS-Bubble-0.1.0-dev-full-stack-validation.img}
    case "$image" in "$repo_root"/*) ;; *) echo 'image must be under repository' >&2; exit 2;; esac
    relative=${image#"$repo_root"/}
    "$repo_root/tests/test-bubble-first-boot-storage.sh"
    exec docker run --rm --platform linux/arm64 \
        -e PLUMOS_BUBBLE_VERIFY_IMAGE="/work/$relative" \
        -v "$repo_root:/work" -w /work "$tools_image" \
        ./scripts/verify-bubble-frontend-probe-image.sh --inside
fi

repo_root=/work
image=${PLUMOS_BUBBLE_VERIFY_IMAGE:?}
prefix=$repo_root/artifacts/vendor/bubble-stock-source/rockchip-boot-prefix.bin
boot_source=$repo_root/artifacts/vendor/bubble-stock-source/boot
system=$repo_root/output/system-rootfs/bubble-frontend/payload/SYSTEM
initramfs=$repo_root/output/initramfs/bubble-external-probe/payload/initramfs-plumos-bubble-external-probe.cpio.gz
base_manifest=${image%/*}/image.manifest
personalized_manifest=$image.manifest
manifest=$base_manifest
personalized=no
if [ -f "$personalized_manifest" ] && \
    grep -q '^format=plumos-bubble-personalized-full-stack-validation-v2$' \
        "$personalized_manifest"; then
    manifest=$personalized_manifest
    personalized=yes
    base_image_sha=$(awk -F= '$1 == "base_image_sha256" {print $2}' "$manifest")
    test "$base_image_sha" = \
        "$(awk -F= '$1 == "image_sha256" {print $2}' "$base_manifest")"
    grep -q '^credential_hash_recorded=no$' "$manifest"
    grep -q '^publishable=no$' "$manifest"
fi
verify=$repo_root/work/bubble-frontend-probe-verify
find "$verify" -depth -delete 2>/dev/null || true
mkdir -p "$verify/matching" "$verify/initramfs"

expected_size=$(awk -F= '$1 == "image_size" {print $2}' "$manifest")
expected_sha=$(awk -F= '$1 == "image_sha256" {print $2}' "$manifest")
expected_p2_sha=$(awk -F= '$1 == "p2_raw_partition_sha256" {print $2}' "$base_manifest")
grep -q '^format=plumos-bubble-full-stack-validation-image-v2$' "$base_manifest"
test "$expected_size" -eq 3036676096
test "$(stat -c '%s' "$image")" = "$expected_size"
test "$(sha256sum "$image" | cut -d' ' -f1)" = "$expected_sha"

parted -ms "$image" unit s print > "$verify/partitions.txt"
grep -q '^1:32768s:1081343s:1048576s:fat32::boot, lba;$' "$verify/partitions.txt"
grep -q '^2:1081344s:1212415s:131072s:::;$' "$verify/partitions.txt"
grep -q '^3:1212416s:5931007s:4718592s:ext4::;$' "$verify/partitions.txt"
! grep -q '^4:' "$verify/partitions.txt"
cmp -i 512:512 -n 16776704 "$prefix" "$image"

dd if="$image" of="$verify/flash.fat" bs=512 skip=32768 count=1048576 status=none
dd if="$image" of="$verify/matching.raw" bs=512 skip=1081344 count=131072 status=none
dd if="$image" of="$verify/runtime.ext4" bs=512 skip=1212416 count=4718592 status=none
test "$(sha256sum "$verify/matching.raw" | cut -d' ' -f1)" = "$expected_p2_sha"
test "$(dd if="$verify/matching.raw" bs=1 count=6 status=none)" = 070701
test -z "$(blkid -p -s TYPE -o value "$verify/matching.raw" 2>/dev/null || true)"
test "$(blkid -s LABEL -o value "$verify/flash.fat")" = PLUMBOOT
test "$(blkid -s LABEL -o value "$verify/runtime.ext4")" = PLUMOS_SYS
fsck.fat -vn "$verify/flash.fat" >/dev/null
e2fsck -fn "$verify/runtime.ext4" >/dev/null

(cd "$verify/matching" && /bin/busybox cpio -idm < "$verify/matching.raw" 2>/dev/null)
(cd "$verify/matching" && sha256sum -c checksums.sha256)
cmp "$boot_source/Image" "$verify/matching/Image"
cmp "$initramfs" "$verify/matching/initramfs-plumos-bubble-external-probe.cpio.gz"
cmp "$boot_source/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/rk3566-gkd-geek-bbg.dtb" \
    "$verify/matching/dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/rk3566-gkd-geek-bbg.dtb"
grep -q '^p2_direct_boot=not-yet-proven$' "$verify/matching/matching-bundle.manifest"
grep -q '^final_p2_format=no$' "$verify/matching/matching-bundle.manifest"

MTOOLS_SKIP_CHECK=1 mcopy -i "$verify/flash.fat" \
    ::/System/system-a.squashfs "$verify/system-a.squashfs"
MTOOLS_SKIP_CHECK=1 mcopy -i "$verify/flash.fat" \
    ::/System/system-b.squashfs "$verify/system-b.squashfs"
cmp "$system" "$verify/system-a.squashfs"
cmp "$system" "$verify/system-b.squashfs"
unsquashfs -d "$verify/system-root" "$verify/system-a.squashfs" >/dev/null
for stage in S39_APP_LAYER_VERIFIED S40_FRONTEND_SUPERVISOR_READY \
    S41_FRONTEND_START E39_APP_LAYER_METADATA_MISSING \
    E39_APP_LAYER_CHECKSUM_FAILED E80_FRONTEND_EXIT E81_FRONTEND_RESTART_LIMIT_RECOVERY_CONSOLE; do
    grep -q "$stage" "$verify/system-root/init"
done
MTOOLS_SKIP_CHECK=1 mtype -i "$verify/flash.fat" ::/System/active-slot | grep -qx a
MTOOLS_SKIP_CHECK=1 mtype -i "$verify/flash.fat" ::/uEnv.txt > "$verify/uEnv.txt"
grep -q '^rootuuid=42554242-4c45-5359-5300-000000000003$' "$verify/uEnv.txt"
grep -q '^initrdimg=initramfs-plumos-bubble-external-probe.cpio.gz$' "$verify/uEnv.txt"
grep -q "plumos_probe_p2_sha256=$expected_p2_sha" "$verify/uEnv.txt"
MTOOLS_SKIP_CHECK=1 mcopy -i "$verify/flash.fat" ::/boot.cmd "$verify/boot.cmd"
for stage in S10 S11 S12 E12 S13 E13 S14 E14 S15 S19 E20; do
    grep -q "$stage" "$verify/boot.cmd"
done
! grep -q fatwrite "$verify/boot.cmd"

gzip -dc "$initramfs" | (cd "$verify/initramfs" && /bin/busybox cpio -idm 2>/dev/null)
for stage in S21 S22 S23 S24 S25 S26 S27 S28 S29 \
    E23 E24 E25 E26 E27 E28 E29; do
    grep -q "$stage" "$verify/initramfs/init"
done
test "$(stat -c '%a' "$verify/initramfs/init")" = 755
test "$(stat -c '%a' "$verify/initramfs/usr/sbin/plumos-bubble-provision-storage")" = 755
for stage in S24A S24B S24C S24D E24A E24B E24C E24D; do
    grep -q "$stage" \
        "$verify/initramfs/usr/sbin/plumos-bubble-provision-storage"
done
for tool in parted partprobe e2fsck resize2fs mkfs.fat fsck.fat; do
    test -x "$verify/initramfs/usr/sbin/$tool"
done
grep -q 'BLANK_P4_WITHOUT_DURABLE_INTENT' \
    "$verify/initramfs/usr/sbin/plumos-bubble-provision-storage"
readelf -h "$verify/initramfs/bin/busybox" | grep -q 'Machine:.*AArch64'

debugfs -R 'cat /plumos/external-initramfs-probe.manifest' \
    "$verify/runtime.ext4" 2>/dev/null > "$verify/runtime.manifest"
grep -q '^format=plumos-bubble-full-stack-runtime-validation-v2$' "$verify/runtime.manifest"
grep -q '^authorized=yes$' "$verify/runtime.manifest"
grep -q '^app_layer=frontend,retroarch,libretro-cores,picoarch,standalone,pyxel,portmaster$' "$verify/runtime.manifest"
grep -q '^partition_expansion=p3-seed-2304MiB-to-8192MiB$' "$verify/runtime.manifest"
grep -q '^p4_creation=first-boot-fat32-PLUMOS$' "$verify/runtime.manifest"
if [ "$personalized" = yes ]; then
    debugfs -R 'stat /plumos/config/wpa_supplicant.conf' \
        "$verify/runtime.ext4" 2>/dev/null | grep -q 'Mode:  0600'
fi

MTOOLS_SKIP_CHECK=1 mtype -i "$verify/flash.fat" \
    ::/plumos-image.manifest > "$verify/plumos-image.manifest"
grep -q '^layout=validation-seed-v2,raw-prefix-16MiB,p1-fat32-512MiB,p2-raw-64MiB,p3-ext4-2304MiB,no-p4$' \
    "$verify/plumos-image.manifest"
grep -q '^format=plumos-bubble-full-stack-validation-image-v2$' "$verify/plumos-image.manifest"
grep -q '^frontend=cpu-drm-dumb-buffer$' "$verify/plumos-image.manifest"
grep -q '^retroarch=software-plain-drm-rgui$' "$verify/plumos-image.manifest"
grep -q '^core_baseline=all-114-source-records$' "$verify/plumos-image.manifest"
grep -q '^catalog_systems=98$' "$verify/plumos-image.manifest"
grep -q '^catalog_launch_profile_occurrences=196$' "$verify/plumos-image.manifest"
grep -q '^user_media_included=no$' "$verify/plumos-image.manifest"
grep -q '^partition_expansion=first-boot-p3-to-8192MiB$' "$verify/plumos-image.manifest"
grep -q '^p4_creation=first-boot-fat32-PLUMOS-to-card-end$' "$verify/plumos-image.manifest"
grep -q '^final_partition_contract=host-candidate$' "$verify/plumos-image.manifest"
grep -q '^publishable=no$' "$verify/plumos-image.manifest"

mkdir -p "$verify/app-layer"
debugfs -R "rdump /plumos $verify/app-layer" "$verify/runtime.ext4" >/dev/null 2>&1
app=$verify/app-layer/plumos
(cd "$app" && sha256sum -c checksums.sha256)
for component in frontend retroarch libretro-cores picoarch standalone pyxel portmaster; do
    (cd "$app" && sha256sum -c "components/$component/checksums.sha256")
done
jq -e '.device == "bubble" and .user_media_included == false and
    .catalog_complete == true and .release_complete == false and
    .publishable == false and .core_baseline == "all-114-source-records"' \
    "$app/manifest.json" >/dev/null
PLUMOS_BUBBLE_APP_ROOT="$app" \
    "$repo_root/scripts/verify-bubble-emulator-catalog.sh"
LD_LIBRARY_PATH="$app/emulator/lib" \
    python3 "$repo_root/scripts/smoke-load-libretro-cores-bubble.py" \
    --root "$app" >"$verify/libretro-load-smoke.log"
grep -Fqx 'bubble_libretro_load_smoke=result-ok pass=114 fail=0' \
    "$verify/libretro-load-smoke.log"
readelf -h "$app/bin/plumos-controller-ui-fbdev" | grep -q 'Machine:.*AArch64'
readelf -h "$app/bin/retroarch" | grep -q 'Machine:.*AArch64'
readelf -h "$app/cores/quicknes_libretro.so" | grep -q 'Machine:.*AArch64'
! readelf -d "$app/bin/retroarch" | grep -Eq 'lib(EGL|GLES|gbm|GL)'
grep -q 'video_driver = "drm"' "$app/factory-defaults/retroarch/retroarch-bubble.cfg"
grep -q 'menu_driver = "rgui"' "$app/factory-defaults/retroarch/retroarch-bubble.cfg"
grep -q 'rgui_show_start_screen = "false"' \
    "$app/factory-defaults/retroarch/retroarch-bubble.cfg"
for entry in ui-settings system-settings network-settings apps help reboot shutdown; do
    grep -q "\"id\": \"$entry\"" "$app/config/frontend/menus.json"
done
grep -q 'PLUMOS_ACTION_TRACE_PATH' "$app/bin/plumos-controller-ui-bubble"
grep -q 'input_device = "retrogame_joypad"' \
    "$app/factory-defaults/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg"
grep -q 'input_a_btn = "1"' \
    "$app/factory-defaults/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg"
grep -q 'input_b_btn = "0"' \
    "$app/factory-defaults/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg"
for script in "$app"/bin/plumos-*; do
    case "$(head -n 1 "$script" 2>/dev/null || true)" in '#!'*) /bin/sh -n "$script" ;; esac
done
! find "$app" -type f \( -iname '*.nes' -o -iname '*.unf' -o -iname '*.unif' \) \
    -print -quit | grep -q .

echo "bubble_frontend_probe_verify=result-ok image=$image sha256=$expected_sha personalized=$personalized"
