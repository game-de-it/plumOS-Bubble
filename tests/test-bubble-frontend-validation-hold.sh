#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch

sh -n "$launcher"
grep -q 'PLUMOS_FRONTEND_VALIDATION_HOLD' "$launcher"
grep -q 'frontend_validation_hold=entered' "$launcher"
grep -q 'while \[ -e "$VALIDATION_HOLD" \]' "$launcher"
grep -q 'frontend_validation_hold=released' "$launcher"
grep -q 'frontend_validation_hold=continue owner=supervisor' "$launcher"
hold_block=$(sed -n '/if \[ -e "$VALIDATION_HOLD" \]; then/,/^fi$/p' "$launcher")
if printf '%s\n' "$hold_block" | grep -q 'exit 0'; then
    printf 'validation hold still exits its PID 1-owned launcher\n' >&2
    exit 1
fi

printf 'bubble_frontend_validation_hold=result-ok scope=tmpfs-root-only\n'
