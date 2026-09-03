#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
systems=$repo_root/package/frontend-bubble/plumos/config/frontend/systems.json
policy=$repo_root/package/frontend-bubble/plumos/config/frontend/rocknix-extension-policy.json
verify=$repo_root/scripts/verify-bubble-emulator-catalog.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

PLUMOS_BUBBLE_SYSTEMS_JSON="$systems" \
PLUMOS_BUBBLE_ROCKNIX_EXTENSION_POLICY="$policy" \
  "$verify" >/dev/null

jq '(.systems[] | select(.id == "pcenginecd") | .extensions) -= ["ccd"]' \
  "$systems" >"$work/missing-required.json"
if PLUMOS_BUBBLE_SYSTEMS_JSON="$work/missing-required.json" \
    PLUMOS_BUBBLE_ROCKNIX_EXTENSION_POLICY="$policy" \
    "$verify" >/dev/null 2>&1; then
  printf 'error: ROCKNIX required-extension removal passed verification\n' >&2
  exit 1
fi

jq '(.systems[] | select(.system_id == "gb") |
      .excluded_extensions[0].reason) = ""' \
  "$policy" >"$work/unexplained-exclusion.json"
if PLUMOS_BUBBLE_SYSTEMS_JSON="$systems" \
    PLUMOS_BUBBLE_ROCKNIX_EXTENSION_POLICY="$work/unexplained-exclusion.json" \
    "$verify" >/dev/null 2>&1; then
  printf 'error: unexplained ROCKNIX extension exclusion passed verification\n' >&2
  exit 1
fi

printf '%s\n' \
  'bubble_rocknix_extension_policy=result-ok systems=98 reference=139 exclusions=30'
