#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mf_root=${PLUMOS_MF_ROOT:-/Users/kroot/plumOS-MF}
source_root="$mf_root/output/network-services/mf/plumos"
out="$repo_root/output/network-services/bubble"
root="$out/plumos"
source_ref=0cc35a6
version=${PLUMOS_BUBBLE_VERSION:-0.1.0-dev}

"$repo_root/scripts/build-network-busybox-bubble.sh"

[[ -d $source_root ]] || { printf 'error: MF network-services input missing: %s\n' "$source_root" >&2; exit 1; }
[[ $(jq -r .source_ref "$source_root/components/network-services/manifest.json") == "$source_ref" ]]
(cd "$source_root" && sha256sum -c components/network-services/checksums.sha256 >/dev/null)

rm -rf "$out"
mkdir -p "$root/network-services/bin" "$root/bin" "$root/components/network-services"
install -m 0755 "$repo_root/output/network-busybox/bubble/busybox" \
    "$root/network-services/bin/busybox"
cp -a "$source_root/ssh" "$root/network-services/"
cp -a "$source_root/samba" "$root/network-services/"
cp -a "$source_root/lib" "$root/network-services/"
install -m 0755 "$repo_root/package/network-services-bubble/plumos/bin/plumos-network-services" \
    "$root/bin/plumos-network-services"

# The imported loader wrappers honor PLUMOS_ROOT, but their payload now lives
# below network-services so it cannot collide with emulator or app libraries.
sed -i.bubble-build 's#${PLUMOS_ROOT}/lib#${PLUMOS_ROOT}/network-services/lib#g; s#${PLUMOS_ROOT}/ssh/#${PLUMOS_ROOT}/network-services/ssh/#g; s#${PLUMOS_ROOT}/samba/#${PLUMOS_ROOT}/network-services/samba/#g' \
    "$root/network-services/ssh/libexec/sftp-server" \
    "$root/network-services/samba/sbin/smbd" \
    "$root/network-services/samba/sbin/nmbd"
rm -f "$root/network-services/ssh/libexec/sftp-server.bubble-build" \
    "$root/network-services/samba/sbin/smbd.bubble-build" \
    "$root/network-services/samba/sbin/nmbd.bubble-build"
for wrapper in "$root/network-services/ssh/libexec/sftp-server" \
    "$root/network-services/samba/sbin/smbd" \
    "$root/network-services/samba/sbin/nmbd"; do
    sed -i.bubble-build \
        '1s|.*|#!/bin/sh|; s#${PLUMOS_ROOT}/bin/busybox#/bin/busybox#g; s#/mnt/SDCARD/plumos#/storage/plumos#g' \
        "$wrapper"
    rm -f "$wrapper.bubble-build"
    grep -Fq 'PLUMOS_ROOT:-/storage/plumos' "$wrapper"
    ! grep -Fq '/mnt/SDCARD/plumos' "$wrapper"
done

cat >"$root/components/network-services/manifest.json" <<EOF
{
  "name": "plumOS Bubble network services",
  "component": "network-services",
  "device": "bubble",
  "version": "$version",
  "source_component": "plumOS-MF network-services@$source_ref",
  "busybox_source": "busybox-1.36.1",
  "busybox_source_archive_sha256": "b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314",
  "services": ["ssh", "ftp", "sftp", "samba"],
  "hardware_unavailable": {"adb": "kernel exposes no USB device controller"},
  "ports": {"ssh": 22, "ftp": 21, "sftp": 22, "samba": 445},
  "mutable_paths": ["config/network/services.conf", "config/network/smb.conf", "logs/network-services.log"]
}
EOF
(
    cd "$root"
    find bin network-services components/network-services/manifest.json -type f -print | LC_ALL=C sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$root/components/network-services/checksums.sha256"
(cd "$root" && sha256sum -c components/network-services/checksums.sha256)
sh -n "$root/bin/plumos-network-services"
printf 'bubble_network_services=result-ok root=%s\n' "$root"
