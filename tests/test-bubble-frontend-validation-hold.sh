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
grep -q 'PLUMOS_DISPLAY_TRACE_ENABLE' "$repo_root/package/frontend-bubble/plumos/bin/plumos-controller-ui-bubble"
grep -q 'PLUMOS_DISPLAY_TRACE_PATH' "$repo_root/package/frontend-bubble/plumos/bin/plumos-controller-ui-bubble"
grep -q 'ui_animation_cpu_boost(ui)' "$repo_root/src/frontend/plumos_controller_ui.c"
grep -q 'ui_animation_cpu_restore(ui)' "$repo_root/src/frontend/plumos_controller_ui.c"
grep -q 'frontend_animation_cpu=boost governor=performance' "$repo_root/src/frontend/plumos_controller_ui.c"
hold_block=$(sed -n '/if \[ -e "$VALIDATION_HOLD" \]; then/,/^fi$/p' "$launcher")
if printf '%s\n' "$hold_block" | grep -q 'exit 0'; then
    printf 'validation hold still exits its PID 1-owned launcher\n' >&2
    exit 1
fi

printf 'bubble_frontend_validation_hold=result-ok scope=tmpfs-root-only\n'
