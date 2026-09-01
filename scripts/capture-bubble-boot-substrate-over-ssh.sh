#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target=${PLUMOS_BUBBLE_SSH_TARGET:-root@192.168.10.101}
password=${PLUMOS_BUBBLE_SSH_PASSWORD:-}
known_hosts=${PLUMOS_BUBBLE_KNOWN_HOSTS:-/tmp/plumos-bubble-known-hosts}
ssh_options="-o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new"
capture_root=$repo_root/artifacts/vendor/bubble-stock-source
incoming=$capture_root/boot-ssh.incoming
expected_prefix=648078e91860adf21bd4ec8f1fd8a64ce52de0ce24511393b156b920327b4ec2

run_ssh() {
    if [ -n "$password" ]; then
        sshpass -p "$password" ssh $ssh_options -o UserKnownHostsFile="$known_hosts" "$target" "$@"
    else
        ssh $ssh_options -o UserKnownHostsFile="$known_hosts" "$target" "$@"
    fi
}

test ! -e "$incoming" || {
    echo "refusing to overwrite prior capture: $incoming" >&2
    exit 1
}
mkdir -p "$incoming"
run_ssh 'flash_source=$(awk '\''$2 == "/flash" {print $1}'\'' /proc/mounts); \
    case "$flash_source" in /dev/mmcblk*p1) os_disk=${flash_source%p1};; *) exit 1;; esac; \
    dd if="$os_disk" bs=1048576 count=16 2>/dev/null' \
    > "$incoming/rockchip-boot-prefix.bin"
test "$(stat -f '%z' "$incoming/rockchip-boot-prefix.bin")" -eq 16777216
test "$(shasum -a 256 "$incoming/rockchip-boot-prefix.bin" | awk '{print $1}')" = "$expected_prefix"

run_ssh 'cd /flash && tar -cf - \
    Image boot.cmd boot.scr uEnv.txt \
    dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/rk3566-gkd-geek-bbg.dtb \
    dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/rk3566-gkd-geek-bbg-hdmi.dtb \
    dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/overlay/rk3568-fiq-debugger-uart2m0.dtbo \
    dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/overlay/rk3568-disable-npu.dtbo \
    dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/rockchip/overlay/rockchip-fixup.scr' \
    | tar -C "$incoming" -xf -

(
    cd "$incoming"
    find . -type f ! -name manifest.sha256 -print | LC_ALL=C sort | while IFS= read -r file; do
        shasum -a 256 "$file"
    done > manifest.sha256
)
for registered in Image boot.cmd boot.scr uEnv.txt; do
    expected=$(awk -v name="$registered" '$2 == name {print $1}' \
        "$repo_root/configs/bubble-stock-active-boot.expected.sha256")
    actual=$(shasum -a 256 "$incoming/$registered" | awk '{print $1}')
    [ -n "$expected" ] && [ "$actual" = "$expected" ]
done
echo "bubble_boot_capture=result-ok root=$incoming"
