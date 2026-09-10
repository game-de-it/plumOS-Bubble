#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
result=$($repo_root/scripts/audit-bubble-vendor-artifacts.py)
case "$result" in
    'bubble_vendor_audit=result-ok '*'private_only=0 publishable=1') ;;
    *) echo "unexpected vendor audit result: $result" >&2; exit 1 ;;
esac

$repo_root/scripts/audit-bubble-vendor-artifacts.py --require-publishable \
    >/dev/null

private_policy=$(mktemp "${TMPDIR:-/tmp}/bubble-private-policy.XXXXXX")
unapproved_policy=$(mktemp "${TMPDIR:-/tmp}/bubble-unapproved-policy.XXXXXX")
trap 'rm -f "$private_policy" "$unapproved_policy"' EXIT HUP INT TERM
jq '.inputs[0].distribution_policy = "private-validation-only"' \
    "$repo_root/configs/bubble-vendor-artifacts.json" >"$private_policy"
if $repo_root/scripts/audit-bubble-vendor-artifacts.py --require-publishable \
    --policy "$private_policy" >/dev/null 2>&1; then
    echo 'public gate accepted a private vendor input' >&2
    exit 1
fi
jq '.inputs[0].distribution_policy = "project-approved-inclusion"' \
    "$repo_root/configs/bubble-vendor-artifacts.json" >"$unapproved_policy"
if $repo_root/scripts/audit-bubble-vendor-artifacts.py \
    --policy "$unapproved_policy" >/dev/null 2>&1; then
    echo 'public gate accepted an unapproved project exception' >&2
    exit 1
fi

grep -Fq 'Copyright (c) 2026 plumOS contributors' "$repo_root/LICENSE"
grep -Fq 'GKD-authored material remain the property of GKD' \
    "$repo_root/docs/licenses/GKD-stockOS-PERMISSION-NOTICE.txt"
grep -Fq 'same project-approved inclusion policy used by plumOS-MF' \
    "$repo_root/docs/licenses/drastic-upstream-NOTICE.txt"
grep -q '^drastic-standalone.*project-approved inclusion$' \
    "$repo_root/docs/licenses/bubble-runtime-license-inventory.tsv"
grep -Fq '"publishable": true' "$repo_root/scripts/build-bubble-app-layer.sh"

printf '%s\n' "$result"
