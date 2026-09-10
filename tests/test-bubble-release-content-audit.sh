#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_root=${PLUMOS_BUBBLE_APP_ROOT:-$repo_root/output/app-layer/bubble/plumos}

result=$($repo_root/scripts/audit-bubble-release-content.py \
    --repo-root "$repo_root" --app-root "$app_root")
case "$result" in
    *'bubble_release_content=result-ok '*'user_media=0 private_keys=0') ;;
    *) echo "unexpected release audit result: $result" >&2; exit 1 ;;
esac

tmp=$(mktemp -d "${TMPDIR:-/tmp}/bubble-release-audit.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cp -R "$app_root" "$tmp/plumos"
mkdir -p "$tmp/plumos/Roms/nes"
printf 'not a real rom\n' >"$tmp/plumos/Roms/nes/fixture.nes"
if $repo_root/scripts/audit-bubble-release-content.py \
    --repo-root "$repo_root" --app-root "$tmp/plumos" >/dev/null 2>&1; then
    echo 'release audit accepted user ROM media' >&2
    exit 1
fi

printf '%s\n' "$result"
