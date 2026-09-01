#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}

if [ "${1:-}" != "--inside" ]; then
    [ "$#" -eq 3 ] || {
        echo "usage: $0 BASE_IMAGE WPA_SUPPLICANT_CONF OUTPUT_IMAGE" >&2
        exit 2
    }
    base=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
    config=$(CDPATH= cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
    output=$(CDPATH= cd -- "$(dirname -- "$3")" && pwd)/$(basename -- "$3")
    case "$base" in "$repo_root"/*) ;; *) echo 'base image must be under repository' >&2; exit 2;; esac
    case "$output" in "$repo_root"/*) ;; *) echo 'output image must be under repository' >&2; exit 2;; esac
    [ -f "$base" ]
    [ -f "$config" ]
    for candidate in "$output" "$output.manifest" "$output.sha256" \
        "$output.incoming"; do
        [ ! -e "$candidate" ] || {
            echo "refusing existing output: $candidate" >&2
            exit 2
        }
    done
    grep -Eq '^[[:space:]]*ctrl_interface=/run/wpa_supplicant([[:space:]]|$)' "$config" || {
        echo 'config must set ctrl_interface=/run/wpa_supplicant' >&2
        exit 2
    }
    grep -Eq '^[[:space:]]*network=\{' "$config" || {
        echo 'config must contain a network block' >&2
        exit 2
    }
    exec docker run --rm --platform linux/arm64 \
        -e BASE_IMAGE="/work/${base#"$repo_root"/}" \
        -e OUTPUT_IMAGE="/work/${output#"$repo_root"/}" \
        -v "$repo_root:/work" -v "$config:/input/wpa_supplicant.conf:ro" \
        -w /work "$tools_image" \
        ./scripts/personalize-bubble-external-initramfs-probe-wifi.sh --inside
fi

base=${BASE_IMAGE:?}
output=${OUTPUT_IMAGE:?}
incoming=$output.incoming
work=/work/work/bubble-external-probe-wifi-personalize
case "$work" in /work/work/bubble-external-probe-wifi-personalize) ;; *) exit 2;; esac
cleanup() {
    rm -f "$incoming"
}
trap cleanup EXIT HUP INT TERM
find "$work" -depth -delete 2>/dev/null || true
mkdir -p "$work" "${output%/*}"

test "$(stat -c '%s' "$base")" -eq 2231369728
cp --sparse=always "$base" "$incoming"
dd if="$incoming" of="$work/runtime.ext4" bs=512 skip=1212416 \
    count=3145728 status=none
debugfs -R 'cat /plumos/external-initramfs-probe.manifest' \
    "$work/runtime.ext4" 2>/dev/null | grep -q '^authorized=yes$'
if debugfs -R 'ls -p /plumos/config' "$work/runtime.ext4" 2>/dev/null | \
    grep -q '/wpa_supplicant.conf/'; then
    echo 'refusing image with existing Wi-Fi configuration' >&2
    exit 2
fi
debugfs -w -R \
    'write /input/wpa_supplicant.conf /plumos/config/wpa_supplicant.conf' \
    "$work/runtime.ext4" >/dev/null 2>&1
debugfs -w -R \
    'set_inode_field /plumos/config/wpa_supplicant.conf mode 0100600' \
    "$work/runtime.ext4" >/dev/null 2>&1
debugfs -w -R \
    'set_inode_field /plumos/config/wpa_supplicant.conf uid 0' \
    "$work/runtime.ext4" >/dev/null 2>&1
debugfs -w -R \
    'set_inode_field /plumos/config/wpa_supplicant.conf gid 0' \
    "$work/runtime.ext4" >/dev/null 2>&1
e2fsck -fn "$work/runtime.ext4" >/dev/null
debugfs -R 'stat /plumos/config/wpa_supplicant.conf' \
    "$work/runtime.ext4" 2>/dev/null | grep -q 'Mode:  0600'
debugfs -R 'dump /plumos/config/wpa_supplicant.conf /work/work/bubble-external-probe-wifi-personalize/readback.conf' \
    "$work/runtime.ext4" >/dev/null 2>&1
cmp /input/wpa_supplicant.conf "$work/readback.conf"
dd if="$work/runtime.ext4" of="$incoming" bs=512 seek=1212416 \
    conv=notrunc status=none
mv "$incoming" "$output"

base_sha=$(sha256sum "$base" | cut -d' ' -f1)
output_sha=$(sha256sum "$output" | cut -d' ' -f1)
cat > "$output.manifest" <<EOF
format=plumos-bubble-personalized-external-initramfs-probe-v1
file=$(basename "$output")
image_size=$(stat -c '%s' "$output")
image_sha256=$output_sha
base_image_sha256=$base_sha
personalization=external-wpa-supplicant-config-in-p3
credential_hash_recorded=no
final_partition_contract=no
publishable=no
EOF
printf '%s  %s\n' "$output_sha" "$(basename "$output")" > "$output.sha256"
echo "bubble_external_probe_wifi_personalize=result-ok output=$output sha256=$output_sha"

