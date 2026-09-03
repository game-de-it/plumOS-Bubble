#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
init="$repo_root/rootfs/bubble-frontend/init"
builder="$repo_root/scripts/build-bubble-frontend-system.sh"
updater="$repo_root/package/frontend-bubble/plumos/share/update/plumos-system-update.py"

sh -n "$init"
grep -q "stage=S39_APP_LAYER_METADATA_READY" "$init"
grep -q "stage=E39_APP_LAYER_METADATA_MISSING" "$init"
grep -q "stage=E39_FRONTEND_REQUIRED_FILE_MISSING" "$init"
grep -q "stage=E39_FRONTEND_LAUNCHER_NOT_EXECUTABLE" "$init"
grep -q '/storage/plumos/bin/plumos-frontend-launch' "$init"
grep -q '/storage/plumos/components/frontend/manifest.json' "$init"
grep -q '/storage/plumos/components/frontend/checksums.sha256' "$init"
! grep -q 'sha256sum -c checksums.sha256' "$init"
grep -q "stage=S34_RECOVERY_NETWORK_BACKGROUND_DISPATCHED" "$init"
grep -q 'PLUMOS_PROVISIONING_COMPLETE="$provisioning_was_complete"' \
    "$repo_root/rootfs/bubble-external-initramfs/init"
grep -q 'clean-shutdown' "$repo_root/rootfs/bubble-external-initramfs/init"
grep -q 'automatic_repair=no' "$repo_root/rootfs/bubble-external-initramfs/init"
grep -q 'mode=completed-no-repair' \
    "$repo_root/rootfs/bubble-external-initramfs/usr/sbin/plumos-bubble-provision-storage"
grep -q 'FILESYSTEM_CHECK_SKIPPED' \
    "$repo_root/rootfs/bubble-external-initramfs/usr/sbin/plumos-bubble-provision-storage"
grep -q '^start_recovery_network_background &$' "$init"
! grep -qx 'start_recovery_network' "$init"
test "$(grep -Fc '[ "$network_stage_fat" -eq 1 ]' "$init")" -eq 1
grep -q '^app_layer_verification=full-at-build-update-deploy,boot-critical-metadata-only$' \
    "$builder"
grep -q '^recovery_network_start=background-before-frontend$' "$builder"
grep -q '^power_finalization=frontend-request,pid1-storage-read-only,forced-kernel-action$' "$builder"
grep -q '^normal_boot=completed-layout-validation-without-filesystem-repair$' \
    "$repo_root/scripts/build-bubble-external-initramfs.sh"
grep -q 'threshold_seconds=10' "$init"
grep -q 'frontend-wait.raw' "$builder"
grep -q 'update_runtime.raw' "$builder"
for stage in update_verify update_runtime update_finalize update_rollback update_error; do
    grep -q "show_progress(\"$stage\")" "$updater"
done

printf '%s\n' \
    'bubble_fast_boot_gate=result-ok boot_full_hash=no critical_metadata=yes wifi=background'
