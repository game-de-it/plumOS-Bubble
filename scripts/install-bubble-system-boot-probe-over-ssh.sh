#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target=${PLUMOS_BUBBLE_SSH_TARGET:-root@192.168.10.101}
password=${PLUMOS_BUBBLE_SSH_PASSWORD:-}
ssh_options="-o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new"
known_hosts=${PLUMOS_BUBBLE_KNOWN_HOSTS:-/tmp/plumos-bubble-known-hosts}

run_ssh() {
    if [ -n "$password" ]; then
        sshpass -p "$password" ssh $ssh_options -o UserKnownHostsFile="$known_hosts" "$target" "$@"
    else
        ssh $ssh_options -o UserKnownHostsFile="$known_hosts" "$target" "$@"
    fi
}

marker=$(run_ssh 'cat /flash/plumos-probe/clone-authorized.txt 2>/dev/null || true')
case "$marker" in
    "PLUMOS_BUBBLE_CLONE_PROBE_V1 "*) ;;
    *)
        echo "refusing install: the running OS SD is not marked as an authorized clone" >&2
        exit 1
        ;;
esac

manifest="$repo_root/work/bubble-system-probe.sha256"
mkdir -p "$repo_root/work"
(
    cd "$repo_root/probe"
    find bin systemd -type f -print | LC_ALL=C sort | while IFS= read -r file; do
        shasum -a 256 "$file"
    done
) > "$manifest"

archive="$repo_root/work/bubble-system-probe.tar"
COPYFILE_DISABLE=1 tar -C "$repo_root/probe" -cf "$archive" bin systemd
remote_root=/storage/plumos/boot-probe
remote_incoming=/storage/plumos/boot-probe.incoming

run_ssh "test ! -e '$remote_root' && test ! -e '$remote_incoming' && mkdir -p '$remote_incoming'"
if [ -n "$password" ]; then
    sshpass -p "$password" scp $ssh_options -o UserKnownHostsFile="$known_hosts" \
        "$archive" "$manifest" "$target:$remote_incoming/"
else
    scp $ssh_options -o UserKnownHostsFile="$known_hosts" \
        "$archive" "$manifest" "$target:$remote_incoming/"
fi

run_ssh "set -eu
    cd '$remote_incoming'
    tar -xf bubble-system-probe.tar
    sha256sum -c bubble-system-probe.sha256
    chmod 0755 bin/plumos-boot-probe-log bin/plumos-boot-probe-snapshot
    : > enabled
    sync
    mv '$remote_incoming' '$remote_root'
    mkdir -p /storage/.config/system.d/miniplus.target.wants
    mkdir -p /storage/.config/system.d/emustation.service.d
    ln -s '$remote_root/systemd/plumos-boot-probe.service' /storage/.config/system.d/plumos-boot-probe.service
    ln -s '$remote_root/systemd/plumos-boot-complete.service' /storage/.config/system.d/plumos-boot-complete.service
    ln -s '$remote_root/systemd/plumos-boot-probe-failure@.service' /storage/.config/system.d/plumos-boot-probe-failure@.service
    ln -s '$remote_root/systemd/plumos-boot-probe.service' /storage/.config/system.d/miniplus.target.wants/plumos-boot-probe.service
    ln -s '$remote_root/systemd/plumos-boot-complete.service' /storage/.config/system.d/miniplus.target.wants/plumos-boot-complete.service
    ln -s '$remote_root/systemd/emustation.service.d/50-plumos-boot-probe.conf' /storage/.config/system.d/emustation.service.d/50-plumos-boot-probe.conf
    sync"

echo "system-stage boot probe installed on authorized clone; reboot was not requested"
