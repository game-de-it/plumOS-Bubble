#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-storage-health
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch

sh -n "$helper"
grep -Fq 'observe >>"$LOG"' "$launcher"
grep -Fq '[ "$MEDIA_ROOT" = /storage ]' "$helper"
test "$(grep -Fc 'plumos-storage-health" observe' "$launcher")" -eq 2
grep -Fq "result=check_refused" "$helper"
grep -Fq "read-only check refused because media is mounted read-write" "$helper"
grep -Fq '"$checker" -n "$device"' "$helper"
if grep -Eq 'fsck\.(fat|vfat).*-[ary]|dosfsck.*-[ary]' "$helper"; then
    echo 'bubble_storage_health=result-failed reason=repair-option-present' >&2
    exit 1
fi
printf 'bubble_storage_health=result-ok startup_observe=yes repair=never mounted_rw_check=refused\n'
