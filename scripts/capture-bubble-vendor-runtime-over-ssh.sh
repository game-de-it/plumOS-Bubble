#!/usr/bin/env bash
set -euo pipefail

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
target=${PLUMOS_BUBBLE_SSH_TARGET:-root@192.168.10.101}
password=${PLUMOS_BUBBLE_SSH_PASSWORD:-plumos}
out="$root_dir/artifacts/vendor/bubble-stock-source/runtime"

[ "${PLUMOS_BUBBLE_CAPTURE_VENDOR:-0}" = 1 ] || {
    printf '%s\n' \
        'error: this creates ignored private vendor captures' \
        'set PLUMOS_BUBBLE_CAPTURE_VENDOR=1 after confirming the stock source device' >&2
    exit 1
}

known_hosts=$(mktemp)
trap 'rm -f "$known_hosts"' EXIT
ssh_opts=(
    -o PreferredAuthentications=password,keyboard-interactive
    -o PubkeyAuthentication=no
    -o NumberOfPasswordPrompts=1
    -o ConnectTimeout=8
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$known_hosts"
)
remote() { sshpass -p "$password" ssh "${ssh_opts[@]}" "$target" "$@"; }
copy() { sshpass -p "$password" scp "${ssh_opts[@]}" "$target:$1" "$2"; }
copy_stream() { remote "cat '$1'" >"$2"; }

identity=$(remote 'printf "%s|" "$(uname -r)"; cat /etc/os-release 2>/dev/null')
case "$identity" in
    4.19.193-g5a07852a55cf-dirty*MINIPLUS*|4.19.193-g5a07852a55cf-dirty*BBG*) ;;
    *) printf 'error: unexpected Bubble source identity: %s\n' "$identity" >&2; exit 1 ;;
esac

mkdir -p "$out/gpu" "$out/modules" "$out/firmware"
copy_stream /proc/config.gz "$out/config.gz"
copy_stream /sys/firmware/fdt "$out/runtime.dtb"
copy /usr/lib/libmali.so.1.9.0 "$out/gpu/libmali-aarch64.so.1.9.0"
armhf=$(remote 'find /storage /usr -type f -name libmali.so.1.9.0 -size -43000k 2>/dev/null | head -n1')
[ -n "$armhf" ] || { printf 'error: ARMhf Mali runtime not found\n' >&2; exit 1; }
copy "$armhf" "$out/gpu/libmali-armhf.so.1.9.0"

for name in bcmdhd.ko dwc3.ko udc-core.ko dwc3-of-simple.ko; do
    path=$(remote "find /usr/lib/kernel-overlays/base/lib/modules -type f -name '$name' 2>/dev/null | head -n1")
    [ -n "$path" ] || { printf 'error: stock module not found: %s\n' "$name" >&2; exit 1; }
    copy "$path" "$out/modules/$name"
done
for name in fw_bcm43438a1.bin nvram_AP6330.txt; do
    path=$(remote "find /usr/lib/kernel-overlays/base/lib/firmware -type f -name '$name' 2>/dev/null | head -n1")
    [ -n "$path" ] || { printf 'error: stock firmware not found: %s\n' "$name" >&2; exit 1; }
    copy "$path" "$out/firmware/$name"
done

remote 'find /usr/lib/kernel-overlays/base/lib/modules -type f -print0 | sort -z | xargs -0 sha256sum | while read -r hash path; do size=$(stat -c %s "$path"); printf "%s\t%s\t%s\n" "$hash" "$size" "$path"; done' >"$out/modules-all.tsv"
remote 'find /usr/lib/kernel-overlays/base/lib/firmware -type f -print0 | sort -z | xargs -0 sha256sum | while read -r hash path; do size=$(stat -c %s "$path"); printf "%s\t%s\t%s\n" "$hash" "$size" "$path"; done' >"$out/firmware-all.tsv"

(cd "$out" && sha256sum -c "$root_dir/configs/bubble-stock-runtime.expected.sha256")
printf 'bubble_vendor_capture=result-ok target=%s output=%s\n' "$target" "$out"
