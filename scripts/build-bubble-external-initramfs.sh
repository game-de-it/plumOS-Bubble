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
        ./scripts/build-bubble-external-initramfs.sh --inside
fi

repo_root=/work
out_dir=$repo_root/output/initramfs/bubble-external-probe
rootfs=$out_dir/rootfs
payload=$out_dir/payload
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}
source_ref=$(git -c safe.directory="$repo_root" -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf unknown)
source_epoch=${SOURCE_DATE_EPOCH:-}
[ -n "$source_epoch" ] || source_epoch=$(git -c safe.directory="$repo_root" -C "$repo_root" show -s --format=%ct HEAD)
case "$source_epoch" in ''|*[!0-9]*) echo 'invalid SOURCE_DATE_EPOCH' >&2; exit 2;; esac

case "$out_dir" in /work/output/initramfs/bubble-external-probe) ;; *) exit 2;; esac
find "$out_dir" -depth -delete 2>/dev/null || true
mkdir -p "$rootfs/bin" "$rootfs/dev/pts" "$rootfs/proc" "$rootfs/sys" \
    "$rootfs/run" "$rootfs/tmp" "$rootfs/root" "$rootfs/mnt" \
    "$rootfs/usr/sbin" "$rootfs/usr/share/plumos" "$payload"
install -m 0755 "$repo_root/rootfs/bubble-external-initramfs/init" "$rootfs/init"
install -m 0755 \
    "$repo_root/rootfs/bubble-external-initramfs/usr/sbin/plumos-bubble-provision-storage" \
    "$rootfs/usr/sbin/plumos-bubble-provision-storage"
install -m 0755 /bin/busybox "$rootfs/bin/busybox"
for applet in awk cat cp dd grep hostname losetup mkdir mknod mount \
    sha256sum sh sleep sync switch_root umount; do
    /bin/busybox --list | grep -qx "$applet"
    ln -s /bin/busybox "$rootfs/bin/$applet"
done

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
for binary in blkid parted partprobe e2fsck resize2fs mkfs.fat fsck.fat; do
    copy_elf "$binary"
done
chroot "$rootfs" /usr/sbin/blkid -V >/dev/null
chroot "$rootfs" /usr/sbin/parted --version >/dev/null
chroot "$rootfs" /usr/sbin/resize2fs -V >/dev/null 2>&1 ||
    chroot "$rootfs" /usr/sbin/resize2fs 2>&1 | grep -q 'Usage:'
chroot "$rootfs" /usr/sbin/mkfs.fat --help >/dev/null 2>&1

shared_boot_logo=$repo_root/package/boot-assets-common/plumos-640x480.bmp
test "$(sha256sum "$shared_boot_logo" | cut -d' ' -f1)" = \
    6b4be39f18289bffe0a9ea65c11f0d479fd12946bd67154ae7332350df795fa8
python3 "$repo_root/scripts/generate-bubble-fb-marker.py" \
    "$shared_boot_logo" "$rootfs/usr/share/plumos/plumos-640x480-xrgb8888.raw"

find "$rootfs" -exec touch -h -d "@$source_epoch" {} +
archive=$payload/initramfs-plumos-bubble-external-probe.cpio.gz
python3 "$repo_root/scripts/pack-bubble-initramfs.py" \
    --mtime "$source_epoch" "$rootfs" "$archive"
archive_size=$(stat -c '%s' "$archive")
archive_sha=$(sha256sum "$archive" | awk '{print $1}')
cat > "$payload/initramfs.manifest" <<EOF
format=plumos-bubble-external-initramfs-provisioning-v2
device=bubble
architecture=aarch64
version=$version
source_ref=$source_ref
source_date_epoch=$source_epoch
kernel_release=4.19.193-g5a07852a55cf-dirty
purpose=authorized-first-boot-storage-provisioning-and-system-ab-boundary
partition_mutation=authorized-p3-expand-to-8192MiB-and-p4-create
runtime_writes=p3-managed-state-and-p4-user-contract
normal_boot=paired-clean-shutdown-markers-skip-filesystem-repair
recovery_boot=missing-clean-marker-runs-filesystem-repair-and-provision-resume
stages=S21-S29,S24A-S24D,E23-E29,E24A-E24D
boot_source=p1-file
p2_boot_source=not-yet-proven
final_partition_contract=host-candidate
publishable=no
image_size=$archive_size
image_sha256=$archive_sha
EOF
printf '%s  %s\n' "$archive_sha" "$(basename "$archive")" \
    > "$payload/checksums.sha256"
gzip -t "$archive"
(cd "$payload" && sha256sum -c checksums.sha256)
echo "bubble_external_initramfs=result-ok image=$archive sha256=$archive_sha"
