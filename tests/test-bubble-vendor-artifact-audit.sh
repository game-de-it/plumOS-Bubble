#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
result=$($repo_root/scripts/audit-bubble-vendor-artifacts.py)
case "$result" in
    'bubble_vendor_audit=result-ok '*'publishable=0') ;;
    *) echo "unexpected vendor audit result: $result" >&2; exit 1 ;;
esac

if $repo_root/scripts/audit-bubble-vendor-artifacts.py --require-publishable \
    >/dev/null 2>&1; then
    echo 'public gate accepted private vendor inputs' >&2
    exit 1
fi

printf '%s\n' "$result"
