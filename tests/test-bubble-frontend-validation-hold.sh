#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-frontend-launch

sh -n "$launcher"
grep -q 'PLUMOS_FRONTEND_VALIDATION_HOLD' "$launcher"
grep -q 'frontend_validation_hold=entered' "$launcher"
grep -q 'while \[ -e "$VALIDATION_HOLD" \]' "$launcher"
grep -q 'frontend_validation_hold=released' "$launcher"

printf 'bubble_frontend_validation_hold=result-ok scope=tmpfs-root-only\n'
