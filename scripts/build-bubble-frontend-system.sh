#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}

if [ "${1:-}" != "--inside" ]; then
    docker image inspect "$image" >/dev/null 2>&1 || \
        "$repo_root/scripts/build-bubble-tools-image.sh"
    exec docker run --rm --platform linux/arm64 \
        -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}" \
        -e PLUMOS_BUBBLE_VERSION="${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}" \
        -v "$repo_root:/work" -w /work "$image" \
        ./scripts/build-bubble-frontend-system.sh --inside
fi

repo_root=/work
out_dir=$repo_root/output/system-rootfs/bubble-frontend
rootfs=$out_dir/rootfs
payload=$out_dir/payload
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
source_epoch=${SOURCE_DATE_EPOCH:-}
[ -n "$source_epoch" ] || source_epoch=$(git -C "$repo_root" show -s --format=%ct HEAD)
case "$source_epoch" in ''|*[!0-9]*) echo 'invalid SOURCE_DATE_EPOCH' >&2; exit 2;; esac

case "$out_dir" in /work/output/system-rootfs/bubble-frontend) ;; *) exit 2;; esac
find "$out_dir" -depth -delete 2>/dev/null || true
mkdir -p "$rootfs" "$payload" "$rootfs/bin" "$rootfs/sbin" \
    "$rootfs/usr/bin" "$rootfs/usr/lib/systemd" "$rootfs/usr/share/plumos" \
    "$rootfs/usr/share/licenses/debian" \
    "$rootfs/dev/pts" "$rootfs/proc" "$rootfs/sys" "$rootfs/flash" \
    "$rootfs/storage" "$rootfs/run" "$rootfs/tmp" "$rootfs/root" \
    "$rootfs/var/empty" "$rootfs/etc/firmware" \
    "$rootfs/lib/modules/4.19.193-g5a07852a55cf-dirty/kernel/drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd"
cp -a "$repo_root/rootfs/bubble-frontend/." "$rootfs/"
install -m 0755 /bin/busybox "$rootfs/bin/busybox"
for applet in cat cut date dmesg grep hostname init ln ls mkdir mount mv poweroff \
    reboot sh sleep sync tail umount ifconfig route insmod ps; do
    ln -s /bin/busybox "$rootfs/bin/$applet"
done
ln -s /init "$rootfs/sbin/init"
ln -s /init "$rootfs/usr/lib/systemd/systemd"
ln -s /bin/busybox "$rootfs/usr/bin/env"

copy_elf() {
    binary=$(command -v "$1")
    destination=$rootfs$binary
    mkdir -p "${destination%/*}"
    install -m 0755 "$binary" "$destination"
    ldd "$binary" 2>/dev/null | awk '
        /=> \// { print $3 }
        /^[[:space:]]*\// { print $1 }
    ' | while IFS= read -r library; do
        [ -f "$library" ] || continue
        mkdir -p "$rootfs${library%/*}"
        install -m 0755 "$library" "$rootfs$library"
    done
}

for binary in wpa_supplicant wpa_cli dropbear dropbearkey; do
    copy_elf "$binary"
done
chmod 0600 "$rootfs/etc/shadow"
chmod 0755 "$rootfs/usr/share/udhcpc/default.script"

runtime=$repo_root/artifacts/vendor/bubble-stock-source/runtime
verify_runtime() {
    registered_name=$1
    artifact=$2
    expected=$(awk -v name="$registered_name" '$2 == name {print $1}' \
        "$repo_root/configs/bubble-stock-runtime.expected.sha256")
    actual=$(sha256sum "$artifact" | cut -d' ' -f1)
    test -n "$expected"
    test "$actual" = "$expected"
}
verify_runtime modules/bcmdhd.ko "$runtime/modules/bcmdhd.ko"
verify_runtime firmware/fw_bcm43438a1.bin "$runtime/firmware/fw_bcm43438a1.bin"
verify_runtime firmware/nvram_AP6330.txt "$runtime/firmware/nvram_AP6330.txt"
install -m 0644 "$runtime/modules/bcmdhd.ko" \
    "$rootfs/lib/modules/4.19.193-g5a07852a55cf-dirty/kernel/drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/bcmdhd.ko"
install -m 0644 "$runtime/firmware/fw_bcm43438a1.bin" \
    "$rootfs/etc/firmware/fw_bcmdhd.bin"
install -m 0644 "$runtime/firmware/fw_bcm43438a1.bin" \
    "$rootfs/etc/firmware/fw_bcm43438a1.bin"
install -m 0644 "$runtime/firmware/nvram_AP6330.txt" \
    "$rootfs/etc/firmware/nvram.txt"
install -m 0644 "$runtime/firmware/nvram_AP6330.txt" \
    "$rootfs/etc/firmware/nvram_ap6212a.txt"
sed -i "s/VERSION_ID=.*/VERSION_ID=\"$version\"/" "$rootfs/etc/os-release"
shared_boot_logo=$repo_root/package/boot-assets-common/plumos-640x480.bmp
test "$(sha256sum "$shared_boot_logo" | cut -d' ' -f1)" = \
    6b4be39f18289bffe0a9ea65c11f0d479fd12946bd67154ae7332350df795fa8
python3 "$repo_root/scripts/generate-bubble-fb-marker.py" \
    "$shared_boot_logo" "$rootfs/usr/share/plumos/bubble-s33-xrgb8888.raw"
printf '%s\n' '4.19.193-g5a07852a55cf-dirty' > "$rootfs/etc/plumos-kernel-abi"
printf '%s\n' "$version" > "$rootfs/etc/plumos-system-version"
install -m 0644 "$repo_root/LICENSE" "$rootfs/usr/share/licenses/plumOS-MIT.txt"
install -m 0644 "$repo_root/docs/licenses/minimal-system-NOTICE.txt" \
    "$rootfs/usr/share/licenses/NOTICE.txt"
install -m 0644 /usr/share/doc/busybox-static/copyright \
    "$rootfs/usr/share/licenses/debian/busybox-static-copyright"
dpkg-query -W -f='${Version}\n' busybox-static > "$rootfs/usr/share/licenses/debian/busybox-static-version"
for package in dropbear-bin libc6 libcap2 libcrypt1 libdbus-1-3 libgcrypt20 \
    libgmp10 libgpg-error0 liblz4-1 liblzma5 libnl-3-200 libnl-genl-3-200 \
    libnl-route-3-200 libpcsclite1 libssl3 libsystemd0 libtomcrypt1 \
    libtommath1 libzstd1 wpasupplicant zlib1g; do
    install -m 0644 "/usr/share/doc/$package/copyright" \
        "$rootfs/usr/share/licenses/debian/$package-copyright"
done

chroot "$rootfs" /usr/sbin/wpa_supplicant -v >/dev/null
chroot "$rootfs" /usr/sbin/dropbear -V >/dev/null 2>&1
strings "$rootfs/lib/modules/4.19.193-g5a07852a55cf-dirty/kernel/drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/bcmdhd.ko" | \
    grep -qx 'vermagic=4.19.193-g5a07852a55cf-dirty SMP mod_unload modversions aarch64'

find "$rootfs" -exec touch -h -d "@$source_epoch" {} +
env -u SOURCE_DATE_EPOCH mksquashfs "$rootfs" "$payload/SYSTEM" -noappend -all-root -no-xattrs \
    -comp xz -mkfs-time "$source_epoch" -all-time "$source_epoch" >/dev/null
system_size=$(stat -c '%s' "$payload/SYSTEM")
system_sha=$(sha256sum "$payload/SYSTEM" | awk '{print $1}')
cat > "$payload/SYSTEM.manifest" <<EOF
format=plumos-bubble-frontend-system-v1
device=bubble
architecture=aarch64
version=$version
source_ref=$source_ref
source_date_epoch=$source_epoch
kernel_release=4.19.193-g5a07852a55cf-dirty
boot_substrate=stock-bubble
entrypoints=/sbin/init,/usr/lib/systemd/systemd
recovery_network=ap6330-bcmdhd,wpa_supplicant,dropbear
boot_visual=shared-plumos-640x480
boot_visual_source_sha256=6b4be39f18289bffe0a9ea65c11f0d479fd12946bd67154ae7332350df795fa8
supervisor=foreground-frontend-with-bounded-restart-and-recovery-console
app_layer_verification=full-at-build-update-deploy,boot-critical-metadata-only
frontend_stages=S39_APP_LAYER_METADATA_READY,S40-S41,E39,E40,E80,E81
bcmdhd_sha256=fd8abaada4aed3ef140e778e344316a1727b0c8d7d9d83d0aee51e3d008297f4
wifi_firmware_sha256=c587abd06865aab98290e1bdd1e9185cfb5c30f89af329c77e0202afe4b932c1
wifi_nvram_sha256=68952ca377ea4f629c7d01042ba6d95e2c74f347a893c4d49a4d3c3f38a5bf1b
image_size=$system_size
image_sha256=$system_sha
EOF
printf '%s  SYSTEM\n' "$system_sha" > "$payload/checksums.sha256"

listing=$out_dir/squashfs-list.txt
unsquashfs -ll "$payload/SYSTEM" > "$listing"
for required in sbin/init usr/lib/systemd/systemd bin/busybox \
    usr/sbin/wpa_supplicant usr/sbin/wpa_cli usr/sbin/dropbear usr/bin/dropbearkey \
    etc/shadow etc/firmware/fw_bcmdhd.bin etc/firmware/fw_bcm43438a1.bin \
    etc/firmware/nvram.txt etc/firmware/nvram_ap6212a.txt \
    lib/modules/4.19.193-g5a07852a55cf-dirty/kernel/drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/bcmdhd.ko \
    usr/share/plumos/bubble-s33-xrgb8888.raw dev proc sys flash storage; do
    grep -q "squashfs-root/$required" "$listing"
done
test "$(stat -c '%s' "$rootfs/usr/share/plumos/bubble-s33-xrgb8888.raw")" -eq 1228800
(cd "$payload" && sha256sum -c checksums.sha256)
echo "bubble_frontend_system=result-ok image=$payload/SYSTEM"
