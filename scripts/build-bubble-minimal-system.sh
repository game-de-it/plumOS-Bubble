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
        ./scripts/build-bubble-minimal-system.sh --inside
fi

repo_root=/work
out_dir=$repo_root/output/system-rootfs/bubble-minimal
rootfs=$out_dir/rootfs
payload=$out_dir/payload
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
source_epoch=${SOURCE_DATE_EPOCH:-}
[ -n "$source_epoch" ] || source_epoch=$(git -C "$repo_root" show -s --format=%ct HEAD)
case "$source_epoch" in ''|*[!0-9]*) echo 'invalid SOURCE_DATE_EPOCH' >&2; exit 2;; esac

case "$out_dir" in /work/output/system-rootfs/bubble-minimal) ;; *) exit 2;; esac
find "$out_dir" -depth -delete 2>/dev/null || true
mkdir -p "$rootfs" "$payload" "$rootfs/bin" "$rootfs/sbin" \
    "$rootfs/usr/bin" "$rootfs/usr/lib/systemd" "$rootfs/usr/share/plumos" \
    "$rootfs/usr/share/licenses/debian" \
    "$rootfs/dev/pts" "$rootfs/proc" "$rootfs/sys" "$rootfs/flash" \
    "$rootfs/storage" "$rootfs/run" "$rootfs/tmp" "$rootfs/root"
cp -a "$repo_root/rootfs/bubble-minimal/." "$rootfs/"
install -m 0755 /bin/busybox "$rootfs/bin/busybox"
for applet in cat cut date dmesg grep hostname init ln ls mkdir mount mv poweroff \
    reboot sh sleep sync tail umount; do
    ln -s /bin/busybox "$rootfs/bin/$applet"
done
ln -s /init "$rootfs/sbin/init"
ln -s /init "$rootfs/usr/lib/systemd/systemd"
ln -s /bin/busybox "$rootfs/usr/bin/env"
sed -i "s/VERSION_ID=.*/VERSION_ID=\"$version\"/" "$rootfs/etc/os-release"
python3 "$repo_root/scripts/generate-bubble-fb-marker.py" \
    "$rootfs/usr/share/plumos/bubble-s33-xrgb8888.raw"
printf '%s\n' '4.19.193-g5a07852a55cf-dirty' > "$rootfs/etc/plumos-kernel-abi"
printf '%s\n' "$version" > "$rootfs/etc/plumos-system-version"
install -m 0644 "$repo_root/LICENSE" "$rootfs/usr/share/licenses/plumOS-MIT.txt"
install -m 0644 "$repo_root/docs/licenses/minimal-system-NOTICE.txt" \
    "$rootfs/usr/share/licenses/NOTICE.txt"
install -m 0644 /usr/share/doc/busybox-static/copyright \
    "$rootfs/usr/share/licenses/debian/busybox-static-copyright"
dpkg-query -W -f='${Version}\n' busybox-static > "$rootfs/usr/share/licenses/debian/busybox-static-version"

find "$rootfs" -exec touch -h -d "@$source_epoch" {} +
env -u SOURCE_DATE_EPOCH mksquashfs "$rootfs" "$payload/SYSTEM" -noappend -all-root -no-xattrs \
    -comp xz -mkfs-time "$source_epoch" -all-time "$source_epoch" >/dev/null
system_size=$(stat -c '%s' "$payload/SYSTEM")
system_sha=$(sha256sum "$payload/SYSTEM" | awk '{print $1}')
cat > "$payload/SYSTEM.manifest" <<EOF
format=plumos-bubble-minimal-system-v1
device=bubble
architecture=aarch64
version=$version
source_ref=$source_ref
source_date_epoch=$source_epoch
kernel_release=4.19.193-g5a07852a55cf-dirty
boot_substrate=stock-bubble
entrypoints=/sbin/init,/usr/lib/systemd/systemd
image_size=$system_size
image_sha256=$system_sha
EOF
printf '%s  SYSTEM\n' "$system_sha" > "$payload/checksums.sha256"

listing=$out_dir/squashfs-list.txt
unsquashfs -ll "$payload/SYSTEM" > "$listing"
for required in sbin/init usr/lib/systemd/systemd bin/busybox \
    usr/share/plumos/bubble-s33-xrgb8888.raw dev proc sys flash storage; do
    grep -q "squashfs-root/$required" "$listing"
done
test "$(stat -c '%s' "$rootfs/usr/share/plumos/bubble-s33-xrgb8888.raw")" -eq 1228800
(cd "$payload" && sha256sum -c checksums.sha256)
echo "bubble_minimal_system=result-ok image=$payload/SYSTEM"
