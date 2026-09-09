#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_IMAGE="${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}"

if [[ ${1:-} != --inside ]]; then
    exec docker run --rm --privileged --platform linux/arm64 \
        -v "$ROOT_DIR:/work:ro" -w /work "$TOOLS_IMAGE" \
        ./tests/test-bubble-first-boot-storage.sh --inside
fi

PROVISIONER=/work/rootfs/bubble-external-initramfs/usr/sbin/plumos-bubble-provision-storage
WORK=$(mktemp -d /tmp/plumos-bubble-storage-test.XXXXXX)
ACTIVE_LOOP=

cleanup() {
    if [[ -n $ACTIVE_LOOP ]]; then
        losetup -d "$ACTIVE_LOOP" 2>/dev/null || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

mknod /dev/loop-control c 10 237 2>/dev/null || true
for number in {0..15}; do
    mknod "/dev/loop$number" b 7 "$number" 2>/dev/null || true
done

wait_partition() {
    local path=$1
    for _ in {1..100}; do
        [[ -b $path ]] && return 0
        sleep 0.05
    done
    return 1
}

attach_image() {
    local image=$1
    ACTIVE_LOOP=$(losetup --find --show --partscan "$image")
    partx -u "$ACTIVE_LOOP" 2>/dev/null || true
    refresh_partition_nodes
    wait_partition "${ACTIVE_LOOP}p3"
}

refresh_partition_nodes() {
    local partition dev_numbers major minor
    for partition in 1 2 3 4; do
        [[ -e "/sys/class/block/${ACTIVE_LOOP##*/}p$partition/dev" ]] || continue
        dev_numbers=$(cat "/sys/class/block/${ACTIVE_LOOP##*/}p$partition/dev")
        major=${dev_numbers%:*}
        minor=${dev_numbers#*:}
        rm -f "${ACTIVE_LOOP}p$partition"
        mknod "${ACTIVE_LOOP}p$partition" b "$major" "$minor"
    done
}

detach_image() {
    partx -d "$ACTIVE_LOOP" 2>/dev/null || true
    losetup -d "$ACTIVE_LOOP"
    rm -f "${ACTIVE_LOOP}"p{1,2,3,4}
    ACTIVE_LOOP=
}

make_seed() {
    local image=$1
    truncate -s $((29360128 * 512)) "$image"
    parted -s "$image" unit s mklabel msdos \
        mkpart primary fat32 32768s 1081343s \
        mkpart primary ext2 1081344s 1212415s \
        mkpart primary ext4 1212416s 5931007s
    attach_image "$image"
    mkfs.ext4 -q -F -L PLUMOS_SYS "${ACTIVE_LOOP}p3"
    detach_image
}

expand_p3_partition_only() {
    local image=$1
    parted -s "$image" unit s resizepart 3 17989631s
}

add_blank_p4() {
    local image=$1
    parted -s -a optimal "$image" unit s \
        mkpart primary fat32 17989632s 100%
}

write_p4_intent() {
    local mountpoint=$WORK/intent-mount
    mkdir -p "$mountpoint"
    mount "${ACTIVE_LOOP}p3" "$mountpoint"
    mkdir -p "$mountpoint/plumos/provision"
    printf '%s\n' 'format=plumos-bubble-p4-create-intent-v1' \
        >"$mountpoint/plumos/provision/p4-create-authorized"
    sync
    umount "$mountpoint"
}

run_provisioner() {
    PLUMOS_BUBBLE_STORAGE_AUTHORIZED=yes \
    PLUMOS_PROVISION_DISK="$ACTIVE_LOOP" \
    PLUMOS_PROVISION_P1="${ACTIVE_LOOP}p1" \
    PLUMOS_PROVISION_P2="${ACTIVE_LOOP}p2" \
    PLUMOS_PROVISION_P3="${ACTIVE_LOOP}p3" \
    PLUMOS_PROVISION_P4="${ACTIVE_LOOP}p4" \
    PLUMOS_PROVISION_STATE_MOUNT="$WORK/state-mount" \
        "$PROVISIONER"
}

run_completed_provisioner() {
    PLUMOS_BUBBLE_STORAGE_AUTHORIZED=yes \
    PLUMOS_PROVISIONING_COMPLETE=yes \
    PLUMOS_PROVISION_DISK="$ACTIVE_LOOP" \
    PLUMOS_PROVISION_P1="${ACTIVE_LOOP}p1" \
    PLUMOS_PROVISION_P2="${ACTIVE_LOOP}p2" \
    PLUMOS_PROVISION_P3="${ACTIVE_LOOP}p3" \
    PLUMOS_PROVISION_P4="${ACTIVE_LOOP}p4" \
    PLUMOS_PROVISION_STATE_MOUNT="$WORK/state-mount" \
        "$PROVISIONER"
}

run_expect_success() {
    local log_file=$1
    if ! run_provisioner >"$log_file" 2>&1; then
        cat "$log_file" >&2
        return 1
    fi
}

assert_final_geometry() {
    refresh_partition_nodes
    if [[ $(blockdev --getsz "${ACTIVE_LOOP}p3") != 16777216 ]]; then return 1; fi
    if [[ $(cat "/sys/class/block/${ACTIVE_LOOP##*/}p4/start") != 17989632 ]]; then return 1; fi
    if [[ $(blkid -s LABEL -o value "${ACTIVE_LOOP}p4") != PLUMOS ]]; then return 1; fi
    if [[ $(blkid -s TYPE -o value "${ACTIVE_LOOP}p4") != vfat ]]; then return 1; fi
    local block_count block_size
    block_count=$(dumpe2fs -h "${ACTIVE_LOOP}p3" 2>/dev/null | awk -F: '/^Block count:/ {gsub(/ /,"",$2); print $2}')
    block_size=$(dumpe2fs -h "${ACTIVE_LOOP}p3" 2>/dev/null | awk -F: '/^Block size:/ {gsub(/ /,"",$2); print $2}')
    if [[ $((block_count * block_size)) != $((16777216 * 512)) ]]; then return 1; fi
}

# Clean seed: expand p3, resize ext4, create and format p4.  A second run must
# preserve both filesystem UUIDs and the partition table.
seed=$WORK/seed.img
make_seed "$seed"
attach_image "$seed"
run_expect_success "$WORK/seed-first.log"
assert_final_geometry
p3_uuid=$(blkid -s UUID -o value "${ACTIVE_LOOP}p3")
p4_uuid=$(blkid -s UUID -o value "${ACTIVE_LOOP}p4")
table_before=$(sfdisk -d "$ACTIVE_LOOP")
run_expect_success "$WORK/seed-second.log"
assert_final_geometry
if [[ $p3_uuid != "$(blkid -s UUID -o value "${ACTIVE_LOOP}p3")" ]]; then exit 1; fi
if [[ $p4_uuid != "$(blkid -s UUID -o value "${ACTIVE_LOOP}p4")" ]]; then exit 1; fi
if [[ $table_before != "$(sfdisk -d "$ACTIVE_LOOP")" ]]; then exit 1; fi
run_completed_provisioner >"$WORK/seed-completed.log" 2>&1
grep -q 'result=ok mode=completed-no-repair' "$WORK/seed-completed.log"
grep -q 'stage=S24B_P3_FILESYSTEM_CHECK_SKIPPED mode=completed-no-repair' \
    "$WORK/seed-completed.log"
grep -q 'stage=S24D_P4_CHECK_SKIPPED .* mode=completed-no-repair' \
    "$WORK/seed-completed.log"
detach_image

# Resume after the p3 partition entry changed but before resize2fs ran.
expanded=$WORK/expanded-only.img
make_seed "$expanded"
expand_p3_partition_only "$expanded"
attach_image "$expanded"
run_expect_success "$WORK/expanded-only.log"
assert_final_geometry
detach_image

# A blank p4 without the durable p3 intent marker is unknown and must not be
# formatted.  The same interrupted state becomes resumable once intent exists.
unknown=$WORK/unknown-p4.img
make_seed "$unknown"
expand_p3_partition_only "$unknown"
add_blank_p4 "$unknown"
attach_image "$unknown"
if run_provisioner >"$WORK/unknown-p4.log" 2>&1; then
    printf 'error: unknown blank p4 was accepted\n' >&2
    exit 1
fi
if [[ -n $(blkid -s TYPE -o value "${ACTIVE_LOOP}p4" 2>/dev/null || true) ]]; then exit 1; fi
write_p4_intent
run_expect_success "$WORK/resumed-p4.log"
assert_final_geometry
detach_image

grep -q 'stage=S24A_P3_PARTITION_EXPANDED' "$WORK/seed-first.log"
grep -q 'stage=S24A_P3_PARTITION_ALREADY_EXPANDED' "$WORK/seed-second.log"
grep -q 'BLANK_P4_WITHOUT_DURABLE_INTENT' "$WORK/unknown-p4.log"
grep -q 'stage=S24C_P4_FORMATTED' "$WORK/resumed-p4.log"
printf 'bubble_first_boot_storage_test=result-ok\n'
