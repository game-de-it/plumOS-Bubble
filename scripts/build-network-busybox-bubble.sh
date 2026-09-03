#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
version=1.36.1
archive="busybox-$version.tar.bz2"
url="https://busybox.net/downloads/$archive"
sha256=b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314
out="$repo_root/output/network-busybox/bubble"

if [[ ${1:-} != --inside ]]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./scripts/build-network-busybox-bubble.sh --inside
fi

repo_root=/work
out="$repo_root/output/network-busybox/bubble"
cache="$repo_root/output/sources/$archive"
build="$repo_root/output/build/network-busybox-$version"
mkdir -p "${cache%/*}" "${build%/*}" "$out"
if [[ ! -f $cache ]] || [[ $(sha256sum "$cache" | awk '{print $1}') != "$sha256" ]]; then
    rm -f "$cache"
    curl -fL --retry 3 -o "$cache" "$url"
fi
echo "$sha256  $cache" | sha256sum -c -
rm -rf "$build"
mkdir -p "$build"
tar -xjf "$cache" -C "$build" --strip-components=1
make -C "$build" defconfig >/dev/null
sed -i \
    -e 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' \
    -e 's/^# CONFIG_TCPSVD is not set$/CONFIG_TCPSVD=y/' \
    -e 's/^# CONFIG_FTPD is not set$/CONFIG_FTPD=y/' \
    -e 's/^# CONFIG_FEATURE_FTPD_WRITE is not set$/CONFIG_FEATURE_FTPD_WRITE=y/' \
    "$build/.config"
make -C "$build" -j"$(nproc)" busybox >/dev/null
install -m 0755 "$build/busybox" "$out/busybox"
strip "$out/busybox"
file "$out/busybox" | grep -q 'ARM aarch64'
file "$out/busybox" | grep -q 'statically linked'
applets=$("$out/busybox" --list)
for applet in tcpsvd ftpd; do
    grep -qx "$applet" <<<"$applets"
done
printf 'bubble_network_busybox=result-ok version=%s sha256=%s\n' \
    "$version" "$(sha256sum "$out/busybox" | awk '{print $1}')"
